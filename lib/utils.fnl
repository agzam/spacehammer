(local fennel (require :fennel))

(fn global-filter
  []
  "
  Filter that includes full-screen apps
  "
  (let [filter (hs.window.filter.new)]
    (: filter :setAppFilter :Emacs {:allowRoles [:AXUnknown :AXStandardWindow :AXDialog :AXSystemDialog]})))

(fn get-or-add-logger [loggers id ?level]
  "If (. loggers id) exists, returns it; otherwise instaniates & stores a new one.
If ?level is provided, sets it on the new or existing hs.logger instance.
`loggers` is expected to be a weak-valued table."
  (case (. loggers id)
    log (do (when ?level (log.setLogLevel ?level))
            log)
    _ (let [log (hs.logger.new id ?level)]
        (tset loggers id log)
        log)))

;; Weak-valued table to store instantiated loggers by ID. Can be called as a
;; function to create & store a new instance, optioanlly with provided log level
(local logger (setmetatable {} {:__mode :v :__call get-or-add-logger}))

{:global-filter global-filter
 : logger}
