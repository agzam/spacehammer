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


(local log (hs.logger.new "apps.fnl", "debug"))

(local actions (atom.new nil))
(var fsm nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Utils
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn gen-key
  []
  (var nums "")
  (for [i 1 7]
    (set nums (.. nums (math.random 0 9))))
  (string.sub (hs.base64.encode nums) 1 7))

(fn emit
  [action data]
  (atom.swap! actions (fn [] [action data])))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Event Dispatchers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn enter
  [app-name]
  (fsm.dispatch :enter-app app-name))

(fn leave
  [app-name]
  (fsm.dispatch :leave-app app-name))

(fn launch
  [app-name]
  (fsm.dispatch :launch-app app-name))

(fn close
  [app-name]
  (fsm.dispatch :close-app app-name))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set Key Bindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn bind-app-keys
  [items]
  (bind-keys items))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Apps Navigation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn by-key
  [target]
  (fn [app]
    (= app.key target)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; State Transitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn general->enter
  [state app-name]
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
  (let [{:apps apps
         :app prev-app
         :unbind-keys unbind-keys} state
        next-app (find (by-key app-name) apps)]
    (if next-app
        (do
          (call-when unbind-keys)
          (lifecycle.deactivate-app prev-app)
          (lifecycle.activate-app next-app)
          {:status :in-app
           :app next-app
           :unbind-keys (bind-app-keys next-app.keys)
           :action :enter-app})
        nil)))

(fn in-app->leave
  [state app-name]
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
  (let [{:apps apps} state
        app-menu (find (by-key app-name) apps)]
    (lifecycle.launch-app app-menu)
    nil))

(fn ->close
  [state app-name]
  (let [{:apps apps} state
        app-menu (find (by-key app-name) apps)]
    (lifecycle.close-app app-menu)
    nil))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finite State Machine States
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local states
       {:general-app {:enter-app  general->enter
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
  (let [app (hs.application.frontmostApplication)]
    (if app
        (: app :name)
        nil)))

(fn start-logger
  [fsm]
  (atom.add-watch
   fsm.state :log-state
   (fn log-state
     [state]
     (log.df "app is now: %s" (and state.app state.app.key)))))

(fn proxy-actions
  [fsm]
  (atom.add-watch fsm.state :actions
                  (fn action-watcher
                    [state]
                    (emit state.action state.app))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; API Methods
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn get-app
  []
  (when fsm
    (let [state (atom.deref fsm.state)]
      state.app)))

(fn subscribe
  [f]
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
