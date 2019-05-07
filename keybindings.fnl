(local utils (require :utils))
(local emacs (require :emacs))

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

(fn enable-local-modals []
  ;; if current app has app-specific config with :app-local-modal key, it allows
  ;; a localized-app-modal, hotkey to invoke the modal should be enabled
  (let [cur-app (current-app-name)
        fsm (: (require :modal) :machine)]
    (each [app-key v (pairs app-specific)]
      (when (and v.app-local-modal (= app-key cur-app))
        (when (not localized-app-modal-hotkey)
          (global
           localized-app-modal-hotkey
           (hs.hotkey.new [:ctrl] :c (fn [] (: fsm :toApplocal)))))
        (: localized-app-modal-hotkey :enable)))))

(fn disable-local-modals []
  ;; if current app doesn't have :app-local-modal key in in app-specific config
  ;; map, localized-app-modal-hotkey should be disabled for that app.
  ;; Example:
  ;; (if localized-app-modal-hotkey set to Ctrl+C) it will conflict with Emacs's
  ;; default keybinding.
  (let [cur-app (current-app-name)
        fsm (: (require :modal) :machine)]
    (when (not (and (. app-specific cur-app)
                    (. (. app-specific cur-app) :app-local-modal)))
      (when localized-app-modal-hotkey
        (: localized-app-modal-hotkey :disable)))))

(global
 app-specific
 {"*"
  {:activated (fn []
                (enable-simple-vi-mode)
                (emacs.enableEditWithEmacs)
                (enable-local-modals))
   :deactivated (fn [] (disable-local-modals))}
  "Emacs"
  {:activated (fn []
                (disable-simple-vi-mode)
                (emacs.disableEditWithEmacs))}

  "Google Chrome"
  {:activated (fn []
                ;; setting conflicting Cmd+L (jump to address bar) keybinding to Cmd+Shift+L
                (let [cmd-sl (hs.hotkey.new [:cmd :shift]
                                            :l
                                            (fn []
                                              (let [app (: (hs.window.focusedWindow) :application)]
                                                (when app
                                                  (: app :selectMenuItem ["File" "Open Location…"])))))]
                  (activate-app-key "Google Chrome", cmd-sl))

                (each [h hk (pairs (simple-tab-switching))]
                  (activate-app-key "Google Chrome" hk)))
   :deactivated (fn [] (deactivate-app-keys "Google Chrome"))
   :app-local-modal
   (fn [self fsm]
     (let [modal  (require :modal)]
       (: self :bind [:ctrl] :c
          (fn []
            (alert "do something crazy in chrome")))
       (fn self.entered []
         (modal.displayModalText "Chrome local modal"))))}

  "iTerm2"
  {:activated (fn []
                (each [h hk (pairs (simple-tab-switching))]
                  (activate-app-key :iTerm2 hk)))
   :deactivated (fn [] (deactivate-app-keys :iTerm2))}

  "Grammarly"
  {:app-local-modal
   (fn [self fsm]
     (let [modal  (require :modal)]
       (: self :bind [:ctrl] :c
          (fn []
            (alert "take text back to Emacs")))
       (: self :bind nil :escape (fn [] (: fsm :toIdle)))
       (fn self.entered []
         (modal.displayModalText "C-c \t- return to Emacs"))))}})

;; watches applications events and if `app-specific` keys exist for the app,
;; enables them for the app, or when the app loses focus - disables them. Also
;; checks for applocal modals and exits modals upon app deactivation
(global
 watcher
 (or
  watcher
  (hs.application.watcher.new
   (fn [app-name event _]
     (let [modal (require :modal)]
      (each [k ev (pairs hs.application.watcher)]
        (when (and (= ev event)
                   (. (. app-specific :*) k))
          ((. (. app-specific :*) k))))

      (each [app modes (pairs app-specific)]
        (when (= app app-name)
          ;; terminated is the same as deactivated, right?
          (when (or
                 (= event hs.application.watcher.deactivated)
                 (= event hs.application.watcher.terminated))
            (when (. modes :deactivated)
              ((. modes :deactivated)))
            (when modal.states.applocal.toIdle
                (modal.states.applocal.toIdle)))

          (each [mode fun (pairs modes)]
            (when (and (= event hs.application.watcher.activated)
                       (= mode :activated))
              (fun))))))))))

(: watcher :start)

{:appSpecific app-specific
 :activateAppKey activate-app-key
 :deactivateAppKeys deactivate-app-keys}
