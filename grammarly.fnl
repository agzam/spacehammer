;; somehow Grammarly doesn't let you easily copy or cut the text out of its
;; window. so I need to emulate a click event first.
(fn click-in-window []
  (let [app (-> (hs.window.focusedWindow) (: :application))
        win (: app :mainWindow)
        frame (: win :frame)
        {:_x x :_y y} frame
        coords  {:x (+ x 100) :y (+ y 100)}]
    (: (hs.eventtap.event.newMouseEvent
        hs.eventtap.event.types.leftMouseDown
        coords) :post)
    (: (hs.eventtap.event.newMouseEvent
        hs.eventtap.event.types.leftMouseUp
        coords) :post)))

(fn back-to-emacs [fsm]
  (let [windows (require :windows)
        run-str (.. "/usr/local/bin/emacsclient"
                    " -e "
                    "'(with-current-buffer (window-buffer (selected-window)) "
                    " (delete-region (region-beginning) (region-end))"
                    " (clipboard-yank))'")
        app (-> (hs.window.focusedWindow) (: :application))]
    (click-in-window)
    (: app :selectMenuItem [:Edit "Select All"])
    (: app :selectMenuItem [:Edit :Cut])
    (hs.timer.usleep 200000)
    (io.popen run-str)
    (hs.application.launchOrFocus :Emacs)
    (: fsm :toIdle)))

(fn add-app-specific []
  (let [keybindings (require :keybindings)]
    (keybindings.add-app-specific
     :Grammarly
     {:launched (fn []
                  ;; there's a bug, when new instance of Grammarly, doesn't
                  ;; activate local modal key, unless rejiggered - de-focused
                  ;; and activated again. Here I'm simply enforcing it
                  (let [keybindings (require :keybindings)]
                    (hs.timer.doAfter 2 keybindings.initialize-local-modals)))
      :app-local-modal
      (fn [self fsm]
        (let [modal  (require :modal)]
          (: self :bind [:ctrl] :c (partial back-to-emacs fsm))
          (: self :bind nil :escape (fn [] (: fsm :toIdle)))
          (fn self.entered []
            (modal.display-modal-text "C-c \t- return to Emacs"))))})))

{:add-app-specific add-app-specific}
