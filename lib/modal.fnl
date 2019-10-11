(local atom (require :lib.atom))
(local statemachine (require :lib.statemachine))
(local apps (require :lib.apps))
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
  (fsm.dispatch :activate menu-key))


(fn deactivate-modal
  []
  (fsm.dispatch :deactivate))


(fn previous-modal
  []
  (fsm.dispatch :previous))


(fn start-modal-timeout
  []
  (fsm.dispatch :start-timeout))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set Key Bindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn create-action-trigger
  [{:action action :repeatable repeatable :timeout timeout}]
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
  (fn []
    (activate-modal key)))


(fn select-trigger
  [item]
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
  {:mods (or item.mods [])
   :key item.key
   :action (select-trigger item)})


(fn bind-menu-keys
  [items]
  (-> items
      (->> (filter (fn [item]
                     (or item.action
                         item.items)))
           (map bind-item))
      (concat [{:key :ESCAPE
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
  (let [mods (-?>> item.mods
                  (map (fn [m] (or (. mod-chars m) m)))
                  (join " "))]
    (.. (or mods "")
        (if mods " + " "")
        item.key)))


(fn modal-alert
  [menu]
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
                [])})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Menus, & Config Navigation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn by-key
  [target]
  (fn [item]
    (and (= (. item :key) target)
         (has-some? item.items))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; State Transitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(fn idle->active
  [state data]
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
  [state data]
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
  (let [{:config config
        :menu prev-menu} state]
    (if (= prev-menu.key config.key)
        nil
        (idle->active state))))


(fn active->submenu
  [state menu-key]
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
  (call-when state.stop-timeout)
  {:stop-timeout (timeout deactivate-modal)})


(fn submenu->previous
  [state]
  (let [{:config config
         :history history} state
        history (slice 1 -1 history)
        main-menu (= 0 (length history))
        navigate (if main-menu
                     idle->active
                     active->submenu)]
    (navigate (merge state
                     {:history history}))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finite State Machine States
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


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
  (atom.add-watch
   fsm.state :log-state
   (fn log-state
     [state]
     (log.df "state is now: %s" state.status))))

(fn proxy-app-action
  [[action data]]
  (fsm.dispatch action data))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn init
  [config]
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
