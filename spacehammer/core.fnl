;; ensure CLI installed
(let [homebrew-silicon-prefix "/opt/homebrew"]
  ;; check package.path for the homebrew's fallpack path to unbreak CLI installs on arm64
  ;; hardware. See https://github.com/Hammerspoon/hammerspoon/pull/3082 for more info.
  (if (string.find package.path homebrew-silicon-prefix)
      (hs.ipc.cliInstall homebrew-silicon-prefix)
      (hs.ipc.cliInstall)))

(local fennel (require :spacehammer.vendor.fennel))
(require :spacehammer.lib.globals)
(local {: file-exists?
        : copy-file
        : watch-files} (require :spacehammer.lib.files))
(local {: map
        : merge
        : reduce} (require :spacehammer.lib.functional))
(local atom (require :spacehammer.lib.atom))
(require-macros :spacehammer.lib.macros)
(require-macros :spacehammer.lib.advice.macros)

;; Add compatability with spoons as the spoon global may not exist at
;; this point until a spoon is loaded. It will exist if a spoon is
;; loaded from init.lua

(global spoon (or _G.spoon {}))

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

(global get-config
        (afn get-config
          []
          "
          Returns the global config object, or error if called early
          "
          (error "get-config can only be called after all modules have initialized")))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create custom config and/or init files if either doesn't exist
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; If ~/.spacehammer/config.fnl does not exist
;; - Create ~/.spacehammer dir
;; - Copy default config.example.fnl to ~/.spacehammer/config.fnl
;; If ~/.spacehammer/init.fnl does not exist
;; - Copy default init.example.fnl to ~/.spacehammer/init.fnl
(let [example-config-path (hs.spoons.resourcePath "config.example.fnl")
      example-init-path (hs.spoons.resourcePath "init.example.fnl")
      target-config-path (.. customdir "/config.fnl")
      target-init-path (.. customdir "/init.fnl")]
  (when (not (file-exists? target-config-path))
    (log.d (.. "Copying " example-config-path " to " target-config-path))
    (hs.fs.mkdir customdir)
    (copy-file example-config-path target-config-path))
  (when (not (file-exists? target-init-path))
    (log.d (.. "Copying " example-init-path " to " target-init-path))
    (copy-file example-init-path target-init-path)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; auto reload config
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Create a global config-files-watcher. Calling it stops the default watcher
(global config-files-watcher (watch-files hs.configdir))

(when (file-exists? (.. customdir "/config.fnl"))
  (global custom-files-watcher (watch-files customdir)))


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
(local modules [:spacehammer.lib.hyper
                :spacehammer.vim
                :spacehammer.windows
                :spacehammer.apps
                :spacehammer.lib.bind
                :spacehammer.lib.modal
                :spacehammer.lib.apps])

(defadvice get-config-impl
           []
           :override get-config
           "Returns global config obj"
           config)

;; Create a global reference so services like hs.application.watcher
;; do not get garbage collected.
(global resources
        (->> modules
             (map (fn [path]
                    (let [module (require path)]
                      {path (module.init config)})))
             (reduce #(merge $1 $2) {})))

