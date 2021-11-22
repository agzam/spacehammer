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
(local {: call-when
        : find
        : merge
        : noop
        : tap}
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
;; Action dispatch functions
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
  (fsm.send :enter-app app-name))

(fn leave
  [app-name]
  "
  The user has deactivated\blurred an app we have config defined.
  Takes the name of the app the user deactivated.
  Transition the state machine to idle from active app state.
  Returns nil.
  "
  (fsm.send :leave-app app-name))

(fn launch
  [app-name]
  "
  The user launched an app we have config defined for.
  Takes name of the app launched.
  Calls the launch lifecycle method defined for an app in config.fnl
  Returns nil.
  "
  (fsm.send :launch-app app-name))

(fn close
  [app-name]
  "
  The user closed an app we have config defined for.
  Takes name of the app closed.
  Calls the exit lifecycle method defined for an app in config.fnl
  Returns nil.
  "
  (fsm.send :close-app app-name))


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
  [state action app-name]
  "
  Transition the app state machine from the general, shared key bindings to an
  app we have local keybindings for.
  Kicks off an effect to bind app-specific keys.
  Takes the current app state machine state table
  Returns update modal state machine state table.
  "
  (let [{: apps
         : app} state.context
        next-app (find (by-key app-name) apps)]
    {:state {:current-state :in-app
             :context {:apps apps
                       :app next-app
                       :prev-app app}}
     :effect :enter-app-effect}))


(fn in-app->leave
  [state action app-name]
  "
  Transition the app state machine from an app the user was using with local
  keybindings to another app that may or may not have local keybindings.
  Because a 'enter (new) app' action is fired before a 'leave (old) app', we
  know that this will be called AFTER the enter transition has updated the
  state, so we should not update the state.
  Takes the current app state machine state table,
  Kicks off an effect to run leave-app effects and unbind the old app's keys
  Returns the old state.
  "
  {:state state
   :effect :leave-app-effect})

(fn launch-app
  [state action app-name]
  "
  Using the state machine we also react to launching apps by calling the :launch
  lifecycle method on apps defined in a user's config.fnl. This way they can run
  hammerspoon functions when an app is opened like say resizing emacs on launch.
  Takes the current app state machine state table.
  Kicks off an effect to bind app-specific keys & fire launch app lifecycle
  Returns a new state.
  "
  (let [{: apps
         : app} state.context
        next-app (find (by-key app-name) apps)]
    {:state {:current-state :in-app
             :context {:apps apps
                       :app next-app
                       :prev-app app}}
     :effect :launch-app-effect}))

(fn ->close
  [state action app-name]
  "
  Using the state machine we also react to launching apps by calling the :close
  lifecycle method on apps defined in a user's config.fnl. This way they can run
  hammerspoon functions when an app is closed. For instance re-enabling vim mode
  when an app is closed that was incompatible
  Takes the current app state machine state table
  Kicks off an effect to bind app-specific keys
  Returns the old state
  "
  {:state state
   :effect :close-app-effect})


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
"

(local states
       {:general-app {:enter-app ->enter
                      :leave-app noop
                      :launch-app launch-app
                      :close-app ->close}
        :in-app {:enter-app ->enter
                 :leave-app in-app->leave
                 :launch-app launch-app
                 :close-app ->close}})


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
     (log.df "app is now: %s" (and state.context.app state.context.app.key)))))

(fn watch-actions
  [{: prev-state : next-state : action : effect : extra}]
  "
  Internal API function to emit app-specific state machine events and transitions to
  other state machines. Like telling our modal state machine the user has
  entered into emacs so display the emacs-specific menu modal.
  Subscribes to the apps state machine.
  Takes a transition record from the FSM.
  Returns nil.
  "
  (emit action next-state.context.app))


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
      state.context.app)))

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

(fn enter-app-effect
  [context]
  "
  Bind keys and lifecycle for the new current app.
  Return a cleanup function to cleanup these bindings.
  "
  (when context.app
    (lifecycle.activate-app context.app)
    (let [unbind-keys (bind-app-keys context.app.keys)]
      (fn []
        (unbind-keys)))))

(fn launch-app-effect
  [context]
  "
  Bind keys and lifecycle for the next current app.
  Return a cleanup function to cleanup these bindings.
  "
  (when context.app
    (lifecycle.launch-app context.app)
    (let [unbind-keys (bind-app-keys context.app.keys)]
      (fn []
        (unbind-keys)))))

(fn app-effect-handler
  [effect-map]
  "
  Takes a map of effect->function and returns a function that handles these
  effects by calling the mapped-to function, and then calls that function's
  return value (a cleanup function) and calls it on the next transition.

  Unlike the fsm's effect-handler, these are app-aware and only call the cleanup
  function for that particular app.

  These functions must return their own cleanup function or nil.
  "
  ;; Create a one-time atom used to store the cleanup function map
  (let [cleanup-ref (atom.new {})]
    ;; Return a subscriber function
    (fn [{: prev-state : next-state : action : effect : extra}]
      ;; Call the cleanup function for this app if it's set
      (call-when (.  (atom.deref cleanup-ref) extra))
      (let [cleanup-map (atom.deref cleanup-ref)
            effect-func (. effect-map effect)]
        ;; Update the cleanup entry for this app with a new func or nil
        (atom.reset! cleanup-ref
                     (merge cleanup-map
                            {extra (call-when effect-func next-state extra)}))))))

(local apps-effect
       (app-effect-handler
         {:enter-app-effect (fn [state extra]
                              (enter-app-effect state.context))
          :leave-app-effect (fn [state extra]
                              (when state.context.prev-app
                                (lifecycle.deactivate-app state.context.prev-app))
                              nil)
          :launch-app-effect (fn [state extra]
                               (launch-app-effect state.context))
          :close-app-effect (fn [state extra]
                              (when state.context.prev-app
                                (lifecycle.close-app state.context.prev-app))
                              nil)}))


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
        initial-context {:apps config.apps
                         :app nil}
        template {:state {:current-state :general-app
                          :context initial-context}
                  :states states
                  :log "apps"}
        app-watcher (hs.application.watcher.new watch-apps)]
    (set fsm (statemachine.new template))
    (fsm.subscribe apps-effect)
    (start-logger fsm)
    (fsm.subscribe watch-actions)
    (enter active-app)
    (: app-watcher :start)
    (fn cleanup []
      (: app-watcher :stop))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


{: init
 : get-app
 : subscribe}
