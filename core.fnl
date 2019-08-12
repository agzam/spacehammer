(hs.console.clearConsole)
(hs.ipc.cliInstall) ; ensure CLI installed

(local fennel (require :fennel))
(local {:contains? contains?
        :for-each  for-each
        :map       map
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
    (hs.reload)))

(fn watch-files
  [dir]
  (let [watcher (hs.pathwatcher.new dir config-reloader)]
    (: watcher :start)
    (fn []
      (: watcher :stop))))

(global config-files-watcher (watch-files hs.configdir))

(when (file-exists? (.. private "/config.fnl"))
  (global custom-files-watcher (watch-files private)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set utility keybindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; toggle hs.console with Ctrl+Cmd+~
(hs.hotkey.bind
 [:ctrl :cmd] "`" nil
 (fn []
   (when-let [console (hs.console.hswindow)]
     (if (= console (hs.window.focusedWindow))
         (-> console (: :application) (: :hide))
         (-> console (: :raise) (: :focus))))))

;; disable annoying Cmd+M for minimizing windows
;; (hs.hotkey.bind [:cmd] :m nil (fn [] nil))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load private init.fnl file (if it exists)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(when (file-exists? (.. private "/init.fnl"))
  (require :private))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize Modals & Apps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local config (require :config))

(local modules [:lib.hyper
                :vim
                :lib.bind
                :lib.modal
                :lib.apps])

(->> modules
     (map require)
     (for-each
      (fn [module]
        (module.init config))))
