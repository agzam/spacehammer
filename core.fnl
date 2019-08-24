(hs.console.clearConsole)
(hs.ipc.cliInstall) ; ensure CLI installed

(local fennel (require :fennel))
(local {:contains? contains?
        :for-each  for-each
        :map       map
        :merge     merge
        :reduce    reduce
        :split     split
        :some      some} (require :lib.functional))
(require-macros :lib.macros)

;; Make private folder override repo files
(local private (.. hs.configdir "/private"))
(tset fennel :path (.. private "/?.fnl;" fennel.path))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; defaults
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(set hs.hints.style :vimperator)
(set hs.hints.showTitleThresh 4)
(set hs.hints.titleMaxSize 10)
(set hs.hints.fontSize 30)
(set hs.window.animationDuration 0.2)

"
alert :: str, { style }, seconds -> nil
Shortcut for showing an alert on the primary screen for a specified duration
Takes a message string, a style table, and the number of seconds to show alert
Returns nil. This function causes side-effects.
"
(global alert (fn
                [str style seconds]
                (hs.alert.show str
                               style
                               (hs.screen.primaryScreen)
                               seconds)))
(global fw hs.window.focusedWindow)

(fn file-exists?
  [filepath]
  "
  Determine if a file exists and is readable.
  Takes a file path string
  Returns true if file is readable
  "
  (let [file (io.open filepath "r")]
    (when file
      (io.close file))
    (~= file nil)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; auto reload config
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn source-filename?
  [file]
  "
  Determine if a file is not an emacs backup file which starts with \".#\"
  Takes a file path string
  Returns true if it's a source file and not an emacs backup file.
  "
  (not (string.match file ".#")))

(fn source-extension?
  [file]
  "
  Determine if a file is a .fnl or .lua file
  Takes a file string
  Returns true if file extension ends in .fnl or .lua
  "
  (let [ext (split "%p" file)]
    (or (contains? "fnl" ext)
        (contains? "lua" ext))))

(fn source-updated?
  [file]
  "
  Determine if a file is a valid source file that we can load
  Takes a file string path
  Returns true if file is not an emacs backup and is a .fnl or .lua type.
  "
  (and (source-filename? file)
       (source-extension? file)))

(fn config-reloader
  [files]
  "
  If the list of files contains some hammerspoon or spacehammer source files:
  reload hammerspoon
  Takes a list of files from our config file watcher.
  Performs side effect of reloading hammerspoon.
  Returns nil
  "
  (when (some source-updated? files)
    (hs.reload)))

(fn watch-files
  [dir]
  "
  Watches hammerspoon or spacehammer source files. When a file updates we reload
  hammerspoon.
  Takes a directory to watch.
  Returns a function to stop the watcher.
  "
  (let [watcher (hs.pathwatcher.new dir config-reloader)]
    (: watcher :start)
    (fn []
      (: watcher :stop))))

;; Create a global config-files-watcher. Calling it stops the default watcher
(global config-files-watcher (watch-files hs.configdir))

;; Create a config-files-watcher for the private dir
(when (file-exists? (.. private "/config.fnl"))
  (global custom-files-watcher (watch-files private)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set utility keybindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; toggle hs.console with Ctrl+Cmd+~
(hs.hotkey.bind
 [:ctrl :cmd] "`" nil
 (fn []
   (if-let
    [console (hs.console.hswindow)]
    (when (= console (hs.console.hswindow))
      (hs.closeConsole))
    (hs.openConsole))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load private init.fnl file (if it exists)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(when (file-exists? (.. private "/init.fnl"))
  (require :private))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize core modules
;; - Requires each module
;; - Calls module.init and provides config.fnl table
;; - Stores global reference to all initialized resources to prevent garbage
;;   collection.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local config (require :config))

;; Initialize our modules that depend on config
(local modules [:lib.hyper
                :vim
                :windows
                :lib.bind
                :lib.modal
                :lib.apps])

;; Create a global reference so services like hs.application.watcher
;; do not get garbage collected.
(global resources
        (->> modules
             (map (fn [path]
                    (let [module (require path)]
                      {path (module.init config)})))
             (reduce #(merge $1 $2) {})))
