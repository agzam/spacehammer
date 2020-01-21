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

(global alert (fn
                [str style seconds]
                (hs.alert.show str
                               style
                               (hs.screen.primaryScreen)
                               seconds)))
(global fw hs.window.focusedWindow)

(fn file-exists?
  [filepath]
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
;; - Copy default ~/.hammerspoon/config.fnl to ~/.spacehammer/config.fnl
(when (not (file-exists? (.. customdir "/config.fnl")))
  (log.d "Copying ~/.hammerspoon/config.fnl to ~/.spacehammer/config.fnl")
  (hs.fs.mkdir customdir)
  (copy-file (.. homedir "/.hammerspoon/config.fnl")
             (.. customdir "/config.fnl")))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; auto reload config
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn source-filename?
  [file]
  (not (string.match file ".#")))

(fn source-extension?
  [file]
  (let [ext (split "%p" file)]
    (or (contains? "fnl" ext)
        (contains? "lua" ext))))

(fn source-updated?
  [file]
  (and (source-filename? file)
       (source-extension? file)))

(fn config-reloader
  [files]
  (when (some source-updated? files)
    (hs.console.clearConsole)
    (hs.reload)))

(fn watch-files
  [dir]
  (let [watcher (hs.pathwatcher.new dir config-reloader)]
    (: watcher :start)
    (fn []
      (: watcher :stop))))

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
;; Initialize Modals & Apps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local config (require :config))

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
