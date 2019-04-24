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

(global
 app-specific
 {"*"
  {:activated (fn []
                (enable-simple-vi-mode)
                (alert "enable edit with emacs"))}
  "Emacs"
  {:activated (fn []
                (disable-simple-vi-mode)
                (alert "disable edit with emacs"))}

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
   :deactivated (fn [] (deactivate-app-keys "Google Chrome"))}

  "iTerm2"
  {:activated (fn []
                (each [h hk (pairs (simple-tab-switching))]
                  (activate-app-key :iTerm2 hk)))
   :deactivated (fn [] (deactivate-app-keys :iTerm2))}})

(global watcher
        (or watcher
            (hs.application.watcher.new
             (fn [app-name event app-obj]
               (each [k v (pairs hs.application.watcher)]
                 (when (and (= v event )
                            (. (. app-specific :*) k))
                   ((. (. app-specific :*) k))))

               (each [app modes (pairs app-specific)]
                 (when (= app app-name)
                   (when (and (= event (. hs.application.watcher :terminated))
                              (. modes :deactivated))
                     ((. modes :deactivated)))
                   (each [mode fun (pairs modes)]
                     (when (= event (. hs.application.watcher mode))
                       (fun)))))))))


(: watcher :start)

{:appSpecific app-specific
 :activateAppKey activate-app-key
 :deactivateAppKeys deactivate-app-keys}
