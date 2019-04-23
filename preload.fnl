(hs.console.clearConsole)
;; ensure CLI installed
(hs.ipc.cliInstall)

;; The default duration for animations, in seconds. Initial value is 0.2; set to 0 to disable animations.
(set hs.window.animationDuration 0.2)

;; globals
(global alert hs.alert.show)
(global log (fn [s] (hs.alert.show (hs.inspect s) 5)))

;; auto reload config
(global
 config-file-pathwatcher
 (hs.pathwatcher.new
  hs.configdir
  (fn [files]
    (let [u hs.fnutils
          fnl-file-change? (u.some
                              files,
                              (fn [p]
                                (let [ext (u.split p "%p")]
                                  (or (u.contains ext "fnl")
                                      (u.contains ext "lua")))))]
      (when fnl-file-change? (hs.reload))))))

(: config-file-pathwatcher :start)
