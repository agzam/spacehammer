(local hyper (require :lib.hyper))
(local {:contains? contains?
        :split     split}
       (require :lib.functional))

(local log (hs.logger.new "bind.fnl" "debug"))

(fn do-action
  [action]
  (let [[file fn-name] (split ":" action)
        module (require file)]
    (if (. module fn-name)
        (: module fn-name)
        (do
          (log.wf "Could not invoke action %s"
                  action)))))


(fn create-action-fn
  [action]
  (fn []
    (do-action action)))


(fn action->fn
  [action]
  (match (type action)
    :function action
    :string (create-action-fn action)
    _         (do
                (log.wf "Could not create action handler for %s"
                        (hs.inspect action))
                (fn [] true))))


(fn bind-keys
  [items]
  (let [modal (hs.hotkey.modal.new [] nil)]
    (each [_ item (ipairs items)]
      (let [{:key key
             :mods mods
             :action action
             :repeat repeat} item
            mods (or mods [])
            action-fn (action->fn action)]
        (if repeat
            (: modal :bind mods key action-fn nil action-fn)
            (: modal :bind mods key nil action-fn))))
    (: modal :enter)
    (fn destroy-bindings
      []
      (when modal
        (: modal :exit)
        (: modal :delete)))))

(fn bind-global-keys
  [items]
  (each [_ item (ipairs items)]
    (let [{:key key} item
          mods (or item.mods [])
          action-fn (action->fn item.action)]
      (if (contains? :hyper mods)
          (hyper.bind key action-fn)
          (let [binding (hs.hotkey.bind mods key action-fn)]
            (fn unbind
              []
              (: binding :delete)))))))

(fn unbind-global-keys
  [bindings]
  (each [_ unbind (ipairs bindings)]
    (unbind)))

(fn init
  [config]
  (let [keys (or config.keys [])
        bindings (bind-global-keys keys)]
    (fn cleanup
      []
      (unbind-global-keys bindings))))

{:init       init
 :action->fn action->fn
 :bind-keys  bind-keys
 :do-action  do-action}
