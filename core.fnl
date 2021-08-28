;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;;
;;; Contributors:
;;   Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;


(hs.ipc.cliInstall) ; ensure CLI installed

(local fennel (require :fennel))
(require :lib.globals)
(local {:contains? contains?
        :for-each  for-each
        :map       map
        :merge     merge
        :reduce    reduce
        :split     split
        :some      some} (require :lib.functional))
(require-macros :lib.macros)

;; Make ~/.spacehammer folder override repo files
(local homedir (os.getenv "HOME"))
(local customdir (.. homedir "/.spacehammer"))
(tset fennel :path (.. customdir "/?.fnl;" fennel.path))

(local log (hs.logger.new "\tcore.fnl\t" "debug"))

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
(global alert (fn [str style seconds]
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
;; create custom config file if it doesn't exist
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn copy-file
  [source dest]
  "
  Copies the contents of a source file to a destination file.
  Takes a source file path and a destination file path.
  Returns nil
  "
  (let [default-config (io.open source "r")
        custom-config (io.open dest "a")]
    (each [line _ (: default-config :lines)]
      (: custom-config :write (.. line "\n")))
    (: custom-config :close)
    (: default-config :close)))

;; If ~/.spacehammer/config.fnl does not exist
;; - Create ~/.spacehammer dir
;; - Copy default ~/.hammerspoon/config.example.fnl to ~/.spacehammer/config.fnl
(let [example-path (.. homedir "/.hammerspoon/config.example.fnl")
      target-path (.. customdir "/config.fnl")]
  (when (not (file-exists? target-path))
    (log.d (.. "Copying " example-path " to " target-path))
    (hs.fs.mkdir customdir)
    (copy-file example-path target-path)))


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
    (and
     (or (contains? "fnl" ext)
         (contains? "lua" ext))
     (not (string.match file "-test%..*$")))))


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
    (hs.console.clearConsole)
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

(when (file-exists? (.. customdir "/config.fnl"))
  (global custom-files-watcher (watch-files customdir)))


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
;; Load custom init.fnl file (if it exists)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(let [custom-init-file (.. customdir "/init.fnl")]
  (when (file-exists? custom-init-file)
    (fennel.dofile custom-init-file)))


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

