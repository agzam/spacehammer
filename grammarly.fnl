;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;;
;;; Contributors:
;;   Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;


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

(fn back-to-emacs
  []
  (let [windows (require :windows)
        run-str (.. "/usr/local/bin/emacsclient"
                    " -e "
                    "'(with-current-buffer (window-buffer (selected-window)) "
                    "   (if (region-active-p)"
                    "      (delete-region (region-beginning) (region-end))"
                    "      (erase-buffer))"
                    " (clipboard-yank))" "'")
        app (-> (hs.window.focusedWindow) (: :application))]
    (click-in-window)
    (: app :selectMenuItem [:Edit "Select All"])
    (: app :selectMenuItem [:Edit :Cut])
    (hs.timer.usleep 200000)
    (io.popen run-str)
    (hs.application.launchOrFocus :Emacs)))

{:back-to-emacs back-to-emacs}
