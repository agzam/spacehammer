(fn add-app-specific []
  (let [keybindings (require :keybindings)]
    (keybindings.add-app-specific
     "Google Chrome"
     {:activated (fn []
                   ;; setting conflicting Cmd+L (jump to address bar) keybinding to Cmd+Shift+L
                   (let [cmd-sl (hs.hotkey.new [:cmd :shift]
                                               :l
                                               (fn []
                                                 (let [app (: (hs.window.focusedWindow) :application)]
                                                   (when app
                                                     (: app :selectMenuItem ["File" "Open Location…"])))))]
                     (keybindings.activate-app-key "Google Chrome", cmd-sl))

                   (each [h hk (pairs (keybindings.simple-tab-switching))]
                     (keybindings.activate-app-key "Google Chrome" hk)))
      :deactivated (fn [] (keybindings.deactivate-app-keys "Google Chrome"))
      :app-local-modal
      (fn [self fsm]
        (let [modal  (require :modal)
              emacs (require :emacs)]
          (: self :bind nil "'"
             (fn []
               (emacs.edit-with-emacs)
               (: (modal.machine) :toIdle)))
          (fn self.entered []
            (modal.display-modal-text "' \tedit-with-emacs\n"))))})))

{:add-app-specific add-app-specific}
