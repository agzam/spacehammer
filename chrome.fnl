
;; setting conflicting Cmd+L (jump to address bar) keybinding to Cmd+Shift+L
(fn cmd-sl []
  (hs.hotkey.new
   [:cmd :shift] :l
   (fn []
     (let [app (: (hs.window.focusedWindow) :application)]
       (when app
         (: app :selectMenuItem ["File" "Open Location…"]))))))

(fn browser-modal [self fsm]
  (let [modal  (require :modal)
        emacs (require :emacs)]
    (: self :bind nil "'"
       (fn []
         (emacs.edit-with-emacs)
         (: (modal.machine) :toIdle)))

    (: self :bind nil :escape (fn [] (: (modal.machine) :toIdle)))

    (fn self.entered []
      (modal.display-modal-text "' \tedit-with-emacs\n"))))

(fn add-app-specific []
  (let [keybindings (require :keybindings)]
    (keybindings.add-app-specific
     "Google Chrome"
     {:activated
      (fn []
        (keybindings.activate-app-key "Google Chrome" (cmd-sl))

        (each [h hk (pairs (keybindings.simple-tab-switching))]
          (keybindings.activate-app-key "Google Chrome" hk)))

      :deactivated (fn [] (keybindings.deactivate-app-keys "Google Chrome"))

      :app-local-modal browser-modal})

    ;; Since Chrome and Brave Browser are very similar, for now related
    ;; functions are placed together
    (keybindings.add-app-specific
     "Brave Browser"
     {:activated
      (fn []
        (keybindings.activate-app-key "Brave Browser" (cmd-sl))

        (each [h hk (pairs (keybindings.simple-tab-switching))]
          (keybindings.activate-app-key "Brave Browser" hk)))

      :deactivated
      (fn [] (keybindings.deactivate-app-keys "Brave Browser"))

      :app-local-modal browser-modal})))

{:add-app-specific add-app-specific}
