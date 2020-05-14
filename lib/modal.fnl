;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

"
Displays the menu modals, sub-menus, and application-specific modals if set
in config.fnl.

We define a state machine, which uses our local states to determine states,
and transitions. Then we can dispatch events that attempt to transition
between specific states defined in the table.

Allows us to create the machinery for displaying, entering, exiting, and
switching menus in one place which is then powered by config.fnl.
"
(local atom (require :lib.atom))
(local statemachine (require :lib.statemachine))
(local apps (require :lib.apps))
(local {:call-when call-when
        :concat    concat
        :find      find
        :filter    filter
        :get       get
        :has-some? has-some?
        :identity  identity
        :join      join
        :last      last
        :map       map
        :merge     merge
        :noop      noop
        :slice     slice
        :tap       tap}
       (require :lib.functional))
(local {:align-columns align-columns}
       (require :lib.text))
(local {:action->fn action->fn
        :bind-keys bind-keys}
       (require :lib.bind))
(local lifecycle (require :lib.lifecycle))

(local log (hs.logger.new "\tmodal.fnl\t" "debug"))
(var fsm nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; General Utils
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn timeout
  [f]
  "
  Create a pre-set timeout task that takes a function to run later.
  Takes a function to call after 2 seconds.
  Returns a function to destroy the timeout task.
  "
  (let [task (hs.timer.doAfter 2 f)]
    (fn destroy-task
      []
      (when task
        (: task :stop)
        nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Event Dispatchers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn activate-modal
  [menu-key]
  "
  API to transition to the active state of our modal finite state machine
  It is called by a trigger set on the outside world and provided relevant
  context to determine which menu modal to activate.
  Takes the name of a menu to activate or nil if it's the root menu.
  menu-key refers to either a submenu key in config.fnl or an application
  specific menu key.
  Side effectful
  "
  (fsm.dispatch :activate menu-key))


(fn deactivate-modal
  []
  "
  API to transition to the idle state of our modal finite state machine.
  Takes no arguments.
  Side effectful
  "
  (fsm.dispatch :deactivate))


(fn previous-modal
  []
  "
  API to transition to the previous modal in our history. Useful for returning
  to the main menu when in the window modal for instance.
  "
  (fsm.dispatch :previous))


(fn start-modal-timeout
  []
  "
  API for starting a menu timeout. Some menu actions like the window navigation
  actions can be repeated without having to re-enter into the Menu
  Modal > Window but we don't want to be listening for key events indefinitely.
  This begins a timeout that will close the modal and remove the key bindings
  after a time delay specified in the timout function.
  Takes no arguments.
  Side effectful
  "
  (fsm.dispatch :start-timeout))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set Key Bindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn create-action-trigger
  [{:action action :repeatable repeatable :timeout timeout}]
  "
  Creates a function to dispatch an action associated with a menu item defined
  by config.fnl.
  Takes a table defining the following:

  action :: function | string - Either a string like \"module:function-name\"
                                or a fennel function to call.
  repeatable :: bool | nil - If this action is repeatable like jumping between
                             windows where we might wish to jump 2 windows
                             left and it wouldn't want to re-enter the jump menu
  timeout :: bool | nil - If a timeout should be started. Defaults to true when
                          repeatable is true.

  Returns a function to execute the action-fn async.
  "
  (let [action-fn (action->fn action)]
    (fn []
      (if (and repeatable (~= timeout false))
          (start-modal-timeout)
          (not repeatable)
          (deactivate-modal))
      ;; Delay the action-fn ever so slightly
      ;; to speed up the closing of the menu
      ;; This makes the UI feel slightly snappier
      (hs.timer.doAfter 0.01 action-fn))))


(fn create-menu-trigger
  [{:key key}]
  "
  Takes a config menu option and returns a function to enter that submenu when
  action is activated.
  Returns a function to activate submenu.
  "
  (fn []
    (activate-modal key)))


(fn select-trigger
  [item]
  "
  Transform a menu item into an action to either call a function or enter a
  submenu.
  Takes a menu item from config.fnl
  Returns a function to perform the action associated with menu item.
  "
  (if (and item.action (= item.action :previous))
      previous-modal
      item.action
      (create-action-trigger item)
      item.items
      (create-menu-trigger item)
      (fn []
        (log.w "No trigger could be found for item: "
               (hs.inspect item)))))


(fn bind-item
  [item]
  "
  Create a bindspec to map modal menu items to actions and submenus.
  Takes a menu item
  Returns a table to create a hs key binding.
  "
  {:mods (or item.mods [])
   :key item.key
   :action (select-trigger item)})


(fn bind-menu-keys
  [items]
  "
  Binds all actions and submenu items within a menu to VenueBook.
  Takes a list of modal menu items.
  Returns a function to remove menu key bindings for easy cleanup.
  "
  (-> items
      (->> (filter (fn [item]
                     (or item.action
                         item.items)))
           (map bind-item))
      (concat [{:key :ESCAPE
                :action deactivate-modal}
               {:mods [:ctrl]
                :key "["
                :action deactivate-modal}])
      (bind-keys)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display Modals
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local mod-chars {:cmd "CMD"
                  :alt "OPT"
                  :shift "SHFT"
                  :tab "TAB"})

(fn format-key
  [item]
  "
  Format the key binding of a menu item to display in a modal menu to user
  Takes a modal menu item
  Returns a string describing the key
  "
  (let [mods (-?>> item.mods
                  (map (fn [m] (or (. mod-chars m) m)))
                  (join " ")
                  (identity))]
    (.. (or mods "")
        (if mods " + " "")
        item.key)))


(fn modal-alert
  [menu]
  "
  Display a menu modal in an hs.alert.
  Takes a menu table specified in config.fnl
  Opens an alert modal as a side effect
  Returns nil
  "
  (let [items (->> menu.items
                   (filter (fn [item] item.title))
                   (map (fn [item]
                          [(format-key item) (. item :title)]))
                   (align-columns))
        text (join "\n" items)]
    (hs.alert.closeAll)
    (alert text
           {:textFont "Menlo"
            :textSize 16
            :radius 0
            :strokeWidth 0}
           99999)))


(fn show-modal-menu
  [{:menu menu
    :prev-menu prev-menu
    :unbind-keys unbind-keys
    :stop-timeout stop-timeout
    :history history}]
  "
  Main API to display a modal and run side-effects
    - Unbind keys of previous modal if set
    - Stop modal timeout that closes the modal after inactivity
    - Call the exit-menu lifecycle method on previous menu if set
    - Call the enter-menu lifecycle method on new menu if set
    - Display the modal alert
  Takes current modal state from our modal statemachine
  Returns updated modal state to store in the modal statemachine
  "
  (call-when unbind-keys)
  (call-when stop-timeout)
  (lifecycle.exit-menu prev-menu)
  (lifecycle.enter-menu menu)
  (modal-alert menu)
  {:menu menu
   :stop-timeout :nil
   :unbind-keys (bind-menu-keys menu.items)
   :history (if history
                (concat [] history [menu])
                [menu])})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Menus, & Config Navigation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn by-key
  [target]
  "
  Checker function to filter menu items where key matches target
  Takes a target string to look for like \"window\"
  Returns true or false
  "
  (fn [item]
    (and (= (. item :key) target)
         (has-some? item.items))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; State Transitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(fn idle->active
  [state data]
  "
  Transition our modal statemachine from the idle state to active where a menu
  modal is displayed to the user.
  Takes the current modal state table plus the key of the menu if submenu
  Displays the modal or local app menu if specified
  Returns updated modal state machine state table.
  "
  (let [{:config config
         :stop-timeout stop-timeout
         :unbind-keys unbind-keys} state
        app-menu (apps.get-app)
        menu (if (and app-menu (has-some? app-menu.items))
                 app-menu
                 config)]
    (merge {:status :active}
           (show-modal-menu {:menu menu
                             :stop-timeout stop-timeout
                             :unbind-keys unbind-keys}))))


(fn active->idle
  [state _]
  "
  Transition our modal state machine from the active, open state to idle by
  closing the modal.
  Takes the current modal state table.
  Closes the modal, stops the close timeout, and unbinds modal keys
  Returns new modal state
  "
  (let [{:menu prev-menu} state]
    (hs.alert.closeAll 0)
    (call-when state.stop-timeout)
    (call-when state.unbind-keys)
    (lifecycle.exit-menu prev-menu)
    {:status :idle
     :menu :nil
     :stop-timeout :nil
     :history []
     :unbind-keys :nil}))


(fn active->enter-app
  [state app-menu]
  "
  Transition our modal state machine that is already open to an app menu
  Takes the current modal state table and the app menu table.
  Displays updated modal menu if the current menu is different than the previous
  menu otherwise results in no operation
  Returns new modal state
  "
  (let [{:config config
         :menu prev-menu
         :stop-timeout stop-timeout
         :unbind-keys unbind-keys
         :history history} state
        menu (if (and app-menu (has-some? app-menu.items))
                 app-menu
                 config)]
    (if (= menu.key prev-menu.key)
        nil
        (merge {:history [menu]}
               (show-modal-menu
                {:stop-timeout stop-timeout
                 :unbind-keys  unbind-keys
                 :menu         menu
                 :history      history})))))


(fn active->leave-app
  [state]
  "
  Transition to the regular menu when user removes focus (blurs) another app.
  If the leave event was fired for the app we are already in, do nothing.
  Takes the current modal state table.
  Returns new updated modal state if we are leaving the current app.
  "
  (let [{:config config
        :menu prev-menu} state]
    (if (= prev-menu.key config.key)
        nil
        (idle->active state))))


(fn active->submenu
  [state menu-key]
  "
  Enter a submenu like entering into the Window menu from the default main menu.
  Takes the current menu state table and the submenu ke.
  Returns updated menu state
  "
  (let [{:config config
         :menu prev-menu
         :stop-timeout stop-timeout
         :unbind-keys unbind-keys
         :history history} state
        menu (if menu-key
                 (find (by-key menu-key) prev-menu.items)
                 config)]
    (when menu
        (merge {:status :submenu}
               (show-modal-menu {:stop-timeout stop-timeout
                                 :unbind-keys  unbind-keys
                                 :prev-menu    prev-menu
                                 :menu         menu
                                 :history      history})))))

(fn active->timeout
  [state]
  "
  Transition from active to idle, but this transition only fires when the
  timeout occurs. The timeout is only started after firing a repeatable action.
  For instance if you enter window > jump east you may want to jump again
  without having to bring up the modal and enter the window submenu. We wait for
  more modal keypresses until the timeout triggers which will deactivate the
  modal.
  Takes the current modal state table.
  Returns a partial modal state table to merge into the modal state.
  "
  (call-when state.stop-timeout)
  {:stop-timeout (timeout deactivate-modal)})

(fn submenu->previous
  [state]
  "
  Transition to the previous submenu. Like if you went into the window menu
  and wanted to go back to the main menu.
  Takes the modal state table.
  Returns a partial modal state table update.
  Dynamically calls another transition depending on history.
  "
  (let [{:config config
         :history history
         :menu menu} state
        prev-menu (. history (- (length history) 1))]
    (if prev-menu
        (merge state
               (show-modal-menu (merge state
                                       {:menu prev-menu
                                        :prev-menu menu}))
               {:history (slice 1 -1 history)})
        (idle->active state))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finite State Machine States
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; State machine states table. Maps states to actions to transition functions.
;; Our state machine implementation is a bit naive in that the transition can
;; return the new state that it's in by updating the status.
;;
;; We can make it more rigid if necessary but can be helpful when navigating
;; submenus or leaving apps.
(local states
       {:idle   {:activate       idle->active
                 :enter-app      noop
                 :leave-app      noop}
        :active {:deactivate     active->idle
                 :activate       active->submenu
                 :start-timeout  active->timeout
                 :enter-app      active->enter-app
                 :leave-app      active->leave-app}
        :submenu {:deactivate    active->idle
                  :activate      active->submenu
                  :previous      submenu->previous
                  :start-timeout active->timeout
                  :enter-app     noop
                  :leave-app     noop}})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Watchers, Dispatchers, & Logging
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(fn start-logger
  [fsm]
  "
  Start logging the status of the modal state machine.
  Takes our finite state machine.
  Returns nil
  Creates a watcher of our state atom to log state changes reactively.
  "
  (atom.add-watch
   fsm.state :log-state
   (fn log-state
     [state]
     (log.df "state is now: %s" state.status)
     (when state.history
       (log.df (hs.inspect (map #(. $1 :title) state.history)))))))

(fn proxy-app-action
  [[action data]]
  "
  Provide a semi-public API function for other state machines to dispatch
  changes to the modal menu state. Currently used by the app state machine to
  tell the modal menu state machine when an app is launched, activated,
  deactivated, or exited.
  Executes a side-effect
  Returns nil
  "
  (fsm.dispatch action data))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn init
  [config]
  "
  Initialize the modal state machine responsible for displaying modal alerts
  to the user to trigger actions defined by their config.fnl.
  Takes the config.fnl table.
  Causes side effects to start the state machine, show the modal, and logging.
  Returns a function to unsubscribe from the app state machine.
  "
  (let [initial-state {:config config
                       :history []
                       :menu nil
                       :status :idle
                       :stop-timeout nil
                       :unbind-keys nil}
        unsubscribe (apps.subscribe proxy-app-action)]
    (set fsm (statemachine.new states initial-state :status))
    (start-logger fsm)
    (fn cleanup []
      (unsubscribe))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


{:init           init
 :activate-modal activate-modal}
