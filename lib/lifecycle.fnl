(local {:do-action do-action} (require :lib.bind))
(local log (hs.logger.new "lifecycle.fnl" "debug"))

(fn do-method
  [obj method-name]
  (let [method (. obj method-name)]
    (match (type method)
      :function (method obj)
      :string (do-action method)
      _       (do
                (log.wf "Could not call lifecycle method %s on %s"
                        method-name
                        obj)))))

(fn activate-app
  [menu]
  (when (and menu menu.activate)
    (do-method menu :activate)))

(fn close-app
  [menu]
  (when (and menu menu.close)
    (do-method menu :close)))

(fn deactivate-app
  [menu]
  (when (and menu menu.deactivate)
    (do-method menu :deactivate)))

(fn enter-menu
  [menu]
  (when (and menu menu.enter)
    (do-method menu :enter)))

(fn exit-menu
  [menu]
  (when (and menu menu.exit)
    (do-method menu :exit)))

(fn launch-app
  [menu]
  (when (and menu menu.launch)
    (do-method menu :launch)))

{:activate-app   activate-app
 :close-app      close-app
 :deactivate-app deactivate-app
 :enter-menu     enter-menu
 :exit-menu      exit-menu
 :launch-app     launch-app}
