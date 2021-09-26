"
Displays the menu modals, sub-menus, and application-specific modals if set
in config.fnl.

We define a state machine, which uses our local states to determine states, and
transitions. Then we can signal events that may transition between specific
states defined in the table.

Allows us to create the machinery for displaying, entering, exiting, and
switching menus in one place which is then powered by config.fnl.
"
(local atom (require :lib.atom))
(local statemachine (require :lib.new-statemachine))
(local om (require :lib.modal)) ;; DELETEME: For PR
(local apps (require :lib.apps))
(local {: butlast
        : call-when
        : concat
        : conj
        : find
        : filter
        : has-some?
        : identity
        : join
        : map
        : merge
        : noop}
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
          (om.start-modal-timeout)
          (not repeatable)
          (om.deactivate-modal))
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
    (om.activate-modal key)))


(fn select-trigger
  [item]
  "
  Transform a menu item into an action to either call a function or enter a
  submenu.
  Takes a menu item from config.fnl
  Returns a function to perform the action associated with menu item.
  "
  (if (and item.action (= item.action :previous))
      om.previous-modal
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
                :action om.deactivate-modal}
               {:mods [:ctrl]
                :key "["
                :action om.deactivate-modal}])
      (bind-keys)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display Modals
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn show-modal-menu
  [{:menu menu}]
  "
  Main API to display a modal and run side-effects
    - Display the modal alert
  Takes current modal state from our modal statemachine
  Returns the function to cleanup everything it sets up
  "
  (lifecycle.enter-menu menu)
  (om.modal-alert menu)
  (let [unbind-keys (bind-menu-keys menu.items)]
    (fn []
      (hs.alert.closeAll 0)
      (unbind-keys)
      (lifecycle.exit-menu menu)
      )))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; State Transition Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(fn idle->active
  [state action extra]
  "
  Transition our modal statemachine from the idle state to active where a menu
  modal is displayed to the user.
  Takes the current modal state table plus the key of the menu if submenu
  Kicks off an effect to display the modal or local app menu
  Returns updated modal state machine state table.
  "
  (let [config state.context.config
        app-menu (apps.get-app)
        menu (if (and app-menu (has-some? app-menu.items))
                 app-menu
                 config)]
    (log.wf "TRANSITION: idle->active app-menu %s menu %s config %s" app-menu menu config) ;; DELETEME
    {:state {:current-state :active
             :context (merge state.context {:menu menu
                                            :history (if state.history
                                                         (conj history menu)
                                                         [menu])})}
     :effect :show-modal-menu}))


(fn active->idle
  [state action extra]
  "
  Transition our modal state machine from the active, open state to idle.
  Takes the current modal state table.
  Kicks off an effect to close the modal, stop the timeout, and unbind keys
  Returns updated modal state machine state table.
  "
  (log.wf "TRANSITION: active->idle") ;; DELETEME
  {:state  {:current-state :idle
            :context (merge state.context {:menu :nil
                                           :history []})}
   :effect :close-modal-menu})


(fn active->enter-app
  [state action extra]
  "
  Transition our modal state machine the main menu to an app menu
  Takes the current modal state table and the app menu table.
  Displays updated modal menu if the current menu is different than the previous
  menu otherwise results in no operation
  Returns new modal state
  "
  (log.wf "TRANSITION: active->enter-app") ;; DELETEME
  (let [{:config config
         :menu prev-menu} state.context
        app-menu (apps.get-app)
        menu (if (and app-menu (has-some? app-menu.items))
                 app-menu
                 config)]
    (if (= menu.key prev-menu.key)
        ; nil transition object means keep all state
        nil
        {:state {:current-state :submenu
                 :context (merge state.context {:menu menu})}
         :effect :open-submenu})))


(fn active->leave-app
  [state action extra]
  "
  Transition to the regular menu when user removes focus (blurs) another app.
  If the leave event was fired for the app we are already in, do nothing.
  Takes the current modal state table.
  Returns new updated modal state if we are leaving the current app.
  "
  (log.wf "TRANSITION: active->leave-app") ;; DELETEME
  (let [{:config config
        :menu prev-menu} state.context]
    (if (= prev-menu.key config.key)
        nil
        (idle->active state action extra))))


(fn active->submenu
  [state action menu-key]
  "
  Enter a submenu like entering into the Window menu from the default main menu.
  Takes the current menu state table and the submenu key as 'extra'.
  Returns updated menu state
  "
  (let [{:config config
         :menu prev-menu} state.context
        menu (if menu-key
                 (find (om.by-key menu-key) prev-menu.items)
                 config)]
    (log.wf "TRANSITION: active->submenu with menu-key %s menu %s" menu-key menu) ;; DELETEME
    {:state {:current-state :submenu
             :context (merge state.context {:menu menu})}
     :effect :open-submenu}))

(fn active->timeout
  [state action extra]
  "
  Transition from active to idle, but this transition only fires when the
  timeout occurs. The timeout is only started after firing a repeatable action.
  For instance if you enter window > jump east you may want to jump again
  without having to bring up the modal and enter the window submenu. We wait for
  more modal keypresses until the timeout triggers which will deactivate the
  modal.
  Takes the current modal state table.
  Returns a the old state with a :stop-timeout added
  "
  (log.wf "TRANSITION: active->timeout") ;; DELETEME
  {:state {:current-state :submenu
           :context
           (merge state.context {:stop-timeout (om.timeout om.deactivate-modal)})}
   :effect :open-submenu})

(fn submenu->previous
  [state action extra]
  "
  Transition to the previous submenu. Like if you went into the window menu
  and wanted to go back to the main menu.
  Takes the modal state table.
  Returns a partial modal state table update.
  Dynamically calls another transition depending on history.
  "
  (let [{:config config
         :history hist
         :menu menu} state.context
        prev-menu (. hist (- (length hist) 1))]
    (log.wf "TRANSITION: submenu->previous") ;; DELETEME
    (if prev-menu
        {:state {:current-state :submenu
                 :context (merge state.context {:menu prev-menu
                                                :history (butlast hist)})}
         :effect :open-submenu}
        (idle->active state))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finite State Machine States
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; State machine states table. Maps states to actions to transition functions.
;; These transition functions return transition objects that contain the new
;; state key and context.
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
     (log.df "state is now: %s" state.current-state) ;; DELETEME
     (when state.context.history
       (log.df (hs.inspect (map #(. $1 :title) state.context.history)))))))

; TODO: Bind show-modal-menu direct
; TODO: Do we only need one effect?
(local modal-effect
       (statemachine.effect-handler
        {:show-modal-menu (fn [state extra]
                            (log.wf "Effect: show modal") ;; DELETEME
                            (show-modal-menu state.context))
         :open-submenu (fn [state extra]
                         (log.wf "Effect: Open submenu with extra %s" extra) ;; DELETEME
                         (show-modal-menu state.context))}))


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
  (let [initial-context {:config config
                         :history []
                         :menu :nil}
        template {:state {:current-state :idle
                          :context initial-context}
                  :states states
                  :log "modal"}
        unsubscribe (apps.subscribe om.proxy-app-action)]
    (set fsm (statemachine.new template))
    (tset fsm :dispatch fsm.signal) ; DELETEME: TEMP: Monkey patch dispatch to show dispatchers haven't changed
    (fsm.subscribe modal-effect)
    (start-logger fsm)
    (fn cleanup []
      (unsubscribe))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


{:init           init
 :activate-modal om.activate-modal}
