(fn add-app-specific []
  (let [keybindings (require :keybindings)]
    (keybindings.add-app-specific
     :Grammarly
     {:app-local-modal
      (fn [self fsm]
        (let [modal  (require :modal)]
          (: self :bind [:ctrl] :c
             (fn []
               (let [run-str (.. "/usr/local/bin/emacsclient"
                                 " -e "
                                 "'(with-current-buffer (window-buffer (selected-window)) (spacemacs/copy-clipboard-to-whole-buffer))'")]
                 (let [app (-> (hs.window.focusedWindow) (: :application))]
                   (let [windows (require :windows)]
                     (windows.set-mouse-cursor-at :Grammarly)
                     (hs.eventtap.event.newMouseEvent hs.eventtap.event.types.leftMouseDown))
                   ;; (: app :selectMenuItem [:Edit "Select All"])
                   ;; (: app :selectMenuItem [:Edit :Cut])
                   ;; (io.popen run-str)
                   ;; (hs.application.launchOrFocus :Emacs)
                   ))))
          (: self :bind nil :escape (fn [] (: fsm :toIdle)))
          (fn self.entered []
            (modal.display-modal-text "C-c \t- return to Emacs"))))})))

{:add-app-specific add-app-specific}
