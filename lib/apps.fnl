;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;;
;;; Contributors:
;;   Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

"
Creates a finite state machine to handle app-specific events.
A user may specify app-specific key bindings or menu items in their config.fnl

Uses a state machine to better organize logic for entering apps we have config
for, versus switching between apps, versus exiting apps, versus activating apps.

This module works mechanically similar to lib/modal.fnl.
"
(local atom (require :lib.atom))
(local statemachine (require :lib.statemachine))
(local os (require :os))
(local {:call-when call-when
        :concat    concat
        :find      find
        :filter    filter
        :get       get
        :has-some? has-some?
        :join      join
        :last      last
        :map       map
        :merge     merge
        :noop      noop
        :slice     slice
        :tap       tap}
       (require :lib.functional))
(local {:action->fn action->fn
        :bind-keys bind-keys}
       (require :lib.bind))
(local lifecycle (require :lib.lifecycle))


(local log (hs.logger.new "apps.fnl" "debug"))

(local actions (atom.new nil))
;; Create a dynamic var to hold an accessible instance of our finite state
;; machine for apps.
(var fsm nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Utils
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn gen-key
  []
  "
  Generate a unique, random, base64 encoded string 7 chars long.
  Takes no arguments.
  Side effectful.
  Returns unique 7 char, randomized string.
  "
  (var nums "")
  (for [i 1 7]
    (set nums (.. nums (math.random 0 9))))
  (string.sub (hs.base64.encode nums) 1 7))

(fn emit
  [action data]
  "
  When an action occurs in our state machine we want to broadcast it for systems
  like modals to transition.
  Takes action name and data to transition another finite state machine.
  Side-effect: Updates the actions atom.
  Returns nil.
  "
  (atom.swap! actions (fn [] [action data])))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Event Dispatchers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn enter
  [app-name]
  "
  Action to focus or activate an app. App must have either menu options
  or key bindings defined in config.fnl.

  Takes the name of the app we entered.
  Transitions to the entered finite-state-machine state.
  Returns nil.
  "
  (fsm.dispatch :enter-app app-name))

(fn leave
  [app-name]
  "
  The user has deactivated\blurred an app we have config defined.
  Takes the name of the app the user deactivated.
  Transition the state machine to idle from active app state.
  Returns nil.
  "
  (fsm.dispatch :leave-app app-name))

(fn launch
  [app-name]
  "
  The user launched an app we have config defined for.
  Takes name of the app launched.
  Calls the launch lifecycle method defined for an app in config.fnl
  Returns nil.
  "
  (fsm.dispatch :launch-app app-name))

(fn close
  [app-name]
  "
  The user closed an app we have config defined for.
  Takes name of the app closed.
  Calls the exit lifecycle method defined for an app in config.fnl
  Returns nil.
  "
  (fsm.dispatch :close-app app-name))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set Key Bindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn bind-app-keys
  [items]
  "
  Bind config.fnl app keys  to actions
  Takes a list of local app bindings
  Returns a function to call without arguments to remove bindings.
  "
  (bind-keys items))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Apps Navigation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn by-key
  [target]
  "
  Checker to search for app definitions to find the app with a key property
  that matches the target.
  Takes a target key string
  Returns a predicate that takes an app menu table and returns true if
  app.key == target
  "
  (fn [app]
    (= app.key target)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; State Transitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn ->enter
  [state app-name]
  "
  Transition the app state machine from the general, shared key bindings to an
  app we have local keybindings for.
  Runs the following side-effects
  - Unbinds the previous app local keys if there were any set
  - Calls the :deactivate method of previous app config.fnl table lifecycle
    precautionary in case it was set by a previous app in use
  - Calls the :activate method of the current app config.fnl table if config
    exists for current app
  Takes the current app state machine state table
  Returns the next app state machine state table
  "
  (let [{:apps apps
         :app prev-app
         :unbind-keys unbind-keys} state
        next-app (find (by-key app-name) apps)]
    (when next-app
      (call-when unbind-keys)
      (lifecycle.deactivate-app prev-app)
      (lifecycle.activate-app next-app)
      {:status :in-app
       :app next-app
       :unbind-keys (bind-app-keys next-app.keys)
       :action :enter-app})))

(fn in-app->enter
  [state app-name]
  "
  Transition the app state machine from an app the user was using with local keybindings
  to another app that may or may not have local keybindings.
  Runs the following side-effects
  - Unbinds the previous app local keys
  - Calls the :deactivate method of previous app config.fnl table lifecycle
  - Calls the :activate method of the current app config.fnl table for the new app
    that we are activating
  Takes the current app state machine state table
  Returns the next app state machine state table
  "
  (let [{:apps apps
         :app prev-app
         :unbind-keys unbind-keys} state
        next-app (find (by-key app-name) apps)]
    (when next-app
      (call-when unbind-keys)
      (lifecycle.deactivate-app prev-app)
      (lifecycle.activate-app next-app)
      {:status :in-app
       :app next-app
       :unbind-keys (bind-app-keys next-app.keys)
       :action :enter-app})))

(fn in-app->leave
  [state app-name]
  "
  Transition the app state machine from an app the user was using with local keybindings
  to another app that may or may not have local keybindings.
  Runs the following side-effects
  - Unbinds the previous app local keys
  - Calls the :deactivate method of previous app config.fnl table lifecycle
  - Calls the :activate method of the current app config.fnl table for the new app
    that we are activating
  Takes the current app state machine state table
  Returns the next app state machine state table
  "
  (let [{:apps         apps
         :app          current-app
         :unbind-keys  unbind-keys} state]
    (if (= current-app.key app-name)
        (do
          (call-when unbind-keys)
          (lifecycle.deactivate-app current-app)
          {:status :general-app
           :app :nil
           :unbind-keys :nil
           :action :leave-app})
        nil)))

(fn ->launch
  [state app-name]
  "
  Using the state machine we also react to launching apps by calling the :launch lifecycle method
  on apps defined in a user's config.fnl. This way they can run hammerspoon functions when an app
  is opened like say resizing emacs on launch.
  Takes the current app state machine state table
  Calls the lifecycle method on the given app config defined in config.fnl
  Returns nil which tells the statemachine that no state updates have ocurred.
  "
  (let [{:apps apps} state
        app-menu (find (by-key app-name) apps)]
    (lifecycle.launch-app app-menu)
    nil))

(fn ->close
  [state app-name]
  "
  Using the state machine we also react to launching apps by calling the :close lifecycle method
  on apps defined in a user's config.fnl. This way they can run hammerspoon functions when an app
  is closed. For instance re-enabling vim mode when an app is closed that was incompatible
  Takes the current app state machine state table
  Calls the lifecycle method on the given app config defined in config.fnl
  Returns nil which tells the statemachine that no state updates have ocurred.
  "
  (let [{:apps apps} state
        app-menu (find (by-key app-name) apps)]
    (lifecycle.close-app app-menu)
    nil))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finite State Machine States
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

"
State machine transition definitions
Defines the two states our app state machine can be in:
1. General, non-specific app where no table defined in config.fnl exists
2. In a specific app where a table is defined to customize local keys,
   modal menu items, or lifecycle methods to trigger other hammerspoon functions
Maps each state to a table of actions mapped to handlers responsible for
returning the next state the statemachine is in.

TODO: Currently each handler function is responsible for performing transition
      side effects like cleaning up previous key bindings and lifecycle methods
      as well as returning the next statemachine state.
      In the near future we can likely separate those responsibilities out more
      akin to something like ClojureScript's re-frame or JS's redux.
"
(local states
       {:general-app {:enter-app  ->enter
                      :leave-app  noop
                      :launch-app ->launch
                      :close-app  ->close}
        :in-app      {:enter-app  in-app->enter
                      :leave-app  in-app->leave
                      :launch-app ->launch
                      :close-app  ->close}})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Watchers, Dispatchers, & Logging
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

"
Assign some simple keywords for each hs.application.watcher event type.
"
(local app-events
       {hs.application.watcher.activated   :activated
        hs.application.watcher.deactivated :deactivated
        hs.application.watcher.hidden      :hidden
        hs.application.watcher.launched    :launched
        hs.application.watcher.launching   :launching
        hs.application.watcher.terminated  :terminated
        hs.application.watcher.unhidden    :unhidden})


(fn watch-apps
  [app-name event app]
  "
  Hammerspoon application watcher callback
  Looks up the event type based on our keyword mappings and dispatches the
  corresponding action against the state machine to manage side-effects and
  update their state.

  Takes the name of the app, the hs.application.watcher event-type, an the
  hs.application.instance that triggered the event.
  Returns nil. Relies on side-effects.
  "
  (let [event-type (. app-events event)]
    (if (= event-type :activated)
        (enter app-name)
        (= event-type :deactivated)
        (leave app-name)
        (= event-type :launched)
        (launch app-name)
        (= event-type :terminated)
        (close app-name))))

(fn active-app-name
  []
  "
  Internal API function to return the name of the frontmost app
  Returns the name of the app if there is a frontmost app or nil.
  "
  (let [app (hs.application.frontmostApplication)]
    (if app
        (: app :name)
        nil)))

(fn start-logger
  [fsm]
  "
  Debugging handler to add a watcher to the apps finite-state-machine
  state atom to log changes over time.
  "
  (atom.add-watch
   fsm.state :log-state
   (fn log-state
     [state]
     (log.df "app is now: %s" (and state.app state.app.key)))))

(fn proxy-actions
  [fsm]
  "
  Internal API function to emit app-specific state machine events and transitions to
  other state machines. Like telling our modal state machine the user has
  entered into emacs so display the emacs-specific menu modal.
  Takes the apps finite state machine instance.
  Performs a side-effect to watch the finite-state-machine and log each action
  to a list of actions other FSMs can subscribe to like a stream.
  Returns nil.
  "
  (atom.add-watch fsm.state :actions
                  (fn action-watcher
                    [state]
                    (emit state.action state.app))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; API Methods
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn get-app
  []
  "
  Public API method to get the user's config table for the current app defined
  in their config.fnl.
  Takes no arguments.
  Returns the current app config table or nil if no config was defined for the
  current app.
  "
  (when fsm
    (let [state (atom.deref fsm.state)]
      state.app)))

(fn subscribe
  [f]
  "
  Public API to subscribe to the stream atom of app specific actions.
  Allows the menu modal FSM to subscribe to app actions to know when to switch
  to an app specific menu or revert back to default main menu.
  Takes a function to call on each action update.
  Returns a function to remove the subscription to actions stream.
  "
  (let [key (gen-key)]
    (atom.add-watch actions key f)
    (fn unsubscribe
      []
      (atom.remove-watch actions key))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn init
  [config]
  "
  Initialize apps finite-state-machine and create hs.application.watcher
  instance to listen for app specific events.
  Takes the current config.fnl table
  Returns a function to cleanup the hs.application.watcher.
  "
  (let [active-app (active-app-name)
        initial-state {:apps config.apps
                       :app nil
                       :status :general-app
                       :unbind-keys nil
                       :action nil}
        app-watcher (hs.application.watcher.new watch-apps)]
    (set fsm (statemachine.new states initial-state :status))
    (start-logger fsm)
    (proxy-actions fsm)
    (enter active-app)
    (: app-watcher :start)
    (fn cleanup []
      (: app-watcher :stop))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


{:init init
 :get-app get-app
 :subscribe subscribe}
