(local utils (require :utils))

(local arrows {:h :left, :j :down,:k :up,:l :right})

(fn simple-tab-switching []
  (let [tbl []]
    (each [dir key (pairs {:j "[" :k "]"})]
      (let [tf (fn [] (hs.eventtap.keyStroke [:shift :cmd] key))]
        (tset tbl dir (hs.hotkey.new [:cmd] dir tf nil tf))))
    tbl))

(global simple-vi-mode-keymaps (or simple-vi-mode-keymaps {}))

(fn enable-simple-vi-mode []
  (each [k v (pairs arrows)]
    (when (not (. simple-vi-mode-keymaps k))
      (tset simple-vi-mode-keymaps k {})
      (table.insert (. simple-vi-mode-keymaps k)
                    (utils.keymap k :alt v nil))
      (table.insert (. simple-vi-mode-keymaps k)
                    (utils.keymap k "alt+shift" v :alt))
      (table.insert (. simple-vi-mode-keymaps k)
                    (utils.keymap k "alt+shift+ctrl" v :shift))))
  (each [_ ks (pairs simple-vi-mode-keymaps)]
    (each [_ k (pairs ks)]
      (: k :enable))))

(fn disable-simple-vi-mode []
  (each [_ ks (pairs simple-vi-mode-keymaps)]
    (each [_ km (pairs ks)]
      (: km :disable))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; App switcher with Cmd++n/p ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(let [switcher (hs.window.switcher.new
                (utils.globalFilter)
                {:textSize 12
                 :showTitles false
                 :showThumbnails false
                 :showSelectedTitle false
                 :selectedThumbnailSize 800
                 :backgroundColor [0 0 0 0]})]
  (hs.hotkey.bind [:cmd] :n (fn [] (: switcher :next)))
  (hs.hotkey.bind [:cmd] :p (fn [] (: switcher :previous))))

(global app-specific-keys (or app-specific-keys {}))

;; Given an app name and hs.hotkey, binds that hotkey when app activates
(fn activate-app-key
  [app hotkey]
  (when (not (. app-specific-keys app))
    (tset app-specific-keys app {}))
  (each [a keys (pairs app-specific-keys)]
    (when (and (or (= a app) (= app :*))
               (not (. keys hotkey.idx)))
      (tset keys hotkey.idx hotkey))
    (each [idx hk (pairs keys)]
      (when (= idx hotkey.idx)
        (: hk :enable)))))

;; disables app-specific hotkeys for a given app name
(fn deactivate-app-keys [app]
  (each [a keys (pairs app-specific-keys)]
    (when (= a app)
      (each [_ hk (pairs keys)]
        (: hk :disable)))))

;; every app is allowed to have a single localized modal that gets dispatched via
(global localized-app-modal-hotkey nil)

(fn current-app-name []
  (-?> (hs.window.frontmostWindow) (: :application) (: :name)))

(global app-specific nil)

(fn initialize-local-modals []
  ;; if current app has app-specific config with :app-local-modal key, it allows
  ;; a localized-app-modal, hotkey to invoke the modal should be enabled
  (let [modal (require :modal)
        fsm (: modal :machine)
        cur-app  (-?> (hs.window.focusedWindow) (: :application) (: :name))
        app-s (-?> app-specific (. cur-app))]
    (when app-s
      (if app-s.app-local-modal
          ;; if current-app has `app-specific' with `:app-local-modal` key
          ;; enable C-c, local-modal key
          (do
            (when (not localized-app-modal-hotkey)
              (global
               localized-app-modal-hotkey
               (hs.hotkey.new [:ctrl] :c (fn [] (: fsm :toApplocal)))))
            (: localized-app-modal-hotkey :enable))
          ;; if current-app doesn't have `app-specific' with `:app-local-modal` key
          ;; - disable C-c, local-modal key
          (when localized-app-modal-hotkey
            (: localized-app-modal-hotkey :disable))))))

(global
 app-specific
 {"*"
  {:activated (fn [app-name]
                (enable-simple-vi-mode)
                (let [emacs (require :emacs)]
                  (emacs.enable-edit-with-emacs))
                (initialize-local-modals))
   :launched (fn [app-name] (initialize-local-modals))
   :unhidden (fn [app-name] (initialize-local-modals))}
  "iTerm2"
  {:activated (fn []
                (each [h hk (pairs (simple-tab-switching))]
                  (activate-app-key :iTerm2 hk)))
   :deactivated (fn [] (deactivate-app-keys :iTerm2))}})

;; (local application-watcher-constants {5 :activated
;;                                       6 :deactivated
;;                                       3 :hidden
;;                                       1 :launched
;;                                       0 :launching
;;                                       2 :terminated
;;                                       4 :unhidden})

(fn deactivating? [event]
  (or (= event hs.application.watcher.deactivated)
      (= event hs.application.watcher.terminated)
      (= event hs.application.watcher.hidden)))

(fn activating? [event]
  (= event hs.application.watcher.activated))

(fn deactivate-local-modals [event]
  (let [modal (require :modal)]
    (when (deactivating? event)
      (when modal.states.applocal.toIdle
        (modal.states.applocal.toIdle)))))

(fn deactivate-local-keys [app-name event]
  (each [app-k m (pairs app-specific)]
    (when (and (activating? event)
           (not= app-k app-name))
      (let [fun (. m :deactivated)]
        (when fun (fun))))))

(fn activate-local-keys [app-name event]
  (when (activating? event)
    (let [fun (-?> app-specific (. app-name)
                   (. :activated))]
      (when fun (fun app-name)))))

(fn activate-local-modal [app-name event]
  (when (activating? event)
    (let [fun (-?> app-specific (. :*) (. :activated))]
      (when fun (fun app-name)))))

(global
 ;; watches applications events and if `app-specific` keys exist for the app,
 ;; enables them for the app, or when the app loses focus - disables them. Also
 ;; checks for applocal modals and exits modals upon app deactivation
 watcher
 (or
  watcher
  (hs.application.watcher.new
   (fn [app-name event _]
     (deactivate-local-modals event)
     (deactivate-local-keys app-name event)
     (activate-local-modal app-name event)
     (activate-local-keys app-name event)))))

(: watcher :start)

(fn add-app-specific [app-name tbl]
  (tset app-specific app-name tbl))

{:disable-simple-vi-mode  disable-simple-vi-mode
 :app-specific            app-specific
 :add-app-specific        add-app-specific
 :activate-app-key        activate-app-key
 :deactivate-app-keys     deactivate-app-keys
 :simple-tab-switching    simple-tab-switching
 :initialize-local-modals initialize-local-modals}
