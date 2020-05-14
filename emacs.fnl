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

(fn capture [is-note]
  "Activates org-capture"
  (let [key         (if is-note "\"z\"" "")
        current-app (hs.window.focusedWindow)
        pid         (.. "\"" (: current-app :pid) "\" ")
        title       (.. "\"" (: current-app :title) "\" ")
        run-str     (..
                     "/usr/local/bin/emacsclient"
                     " -c -F '(quote (name . \"capture\"))'"
                     " -e '(spacehammer/activate-capture-frame "
                     pid title key " )' &")
        timer       (hs.timer.delayed.new .1 (fn [] (io.popen run-str)))]
    (: timer :start)))

(fn edit-with-emacs []
  "Executes emacsclient, evaluating a special elisp function in spacehammer.el
   (it must be pre-loaded), passing PID, title and display-id of the caller."
  (let [current-app (: (hs.window.focusedWindow) :application)
        pid         (.. "\"" (: current-app :pid) "\"")
        title       (.. "\"" (: current-app :title) "\"")
        screen      (.. "\"" (: (hs.screen.mainScreen) :id) "\"")
        run-str     (..
                     "/usr/local/bin/emacsclient"
                     " -c -F '(quote (name . \"edit\"))' "
                     " -e '(spacehammer/edit-with-emacs "
                     pid " " title " " screen " )' &")
        co          (coroutine.create (fn [run-str]
                                        (io.popen run-str)))
        prev        (hs.pasteboard.changeCount)
        _           (hs.eventtap.keyStroke [:cmd] :c)
        next        (hs.pasteboard.changeCount)]
    (when (= prev next)         ; Pasteboard was not updated so no text was selected
      (hs.eventtap.keyStroke [:cmd] :a)  ; select all
      (hs.eventtap.keyStroke [:cmd] :c)  ; copy
      )
    (coroutine.resume co run-str)))

(fn edit-with-emacs-callback [pid title screen]
  "Don't remove! - this is callable from Emacs
   See: `spacehammer/edit-with-emacs` in spacehammer.el"
  (let [emacs-app   (hs.application.get :Emacs)
        edit-window (: emacs-app :findWindow :edit)
        scr         (hs.screen.find (tonumber screen))
        windows     (require :windows)]
    (when (and edit-window scr)
      (: edit-window :moveToScreen scr)
      (: windows :center-window-frame))))

(fn run-emacs-fn
  [elisp-fn args]
  "Executes given elisp function in emacsclient. If args table present, passes
   them into the function."
  (let [args-lst (when args (.. " '" (table.concat args " '")))
        run-str  (.. "/usr/local/bin/emacsclient"
                     " -e \"(funcall '" elisp-fn
                     (if args-lst args-lst " &")
                     ")\" &")]
    (io.popen run-str)))

(fn full-screen
  []
  "Switches to current instance of GUI Emacs and makes its frame fullscreen"
  (hs.application.launchOrFocus :Emacs)
  (run-emacs-fn
   (..
    "(lambda ())"
    "(spacemacs/toggle-fullscreen-frame-on)"
    "(spacehammer/fix-frame)")))

(fn vertical-split-with-emacs
  []
  "Creates vertical split with Emacs window sitting next to the current app"
  (let [windows    (require :windows)
        cur-app    (-?> (hs.window.focusedWindow) (: :application) (: :name))
        rect-left  [0  0 .5  1]
        rect-right [.5 0 .5  1]
        elisp      (.. "(lambda ()"
                       " (spacemacs/toggle-fullscreen-frame-off) "
                       " (spacemacs/maximize-horizontally) "
                       " (spacemacs/maximize-vertically))")]
    (run-emacs-fn elisp)
    (hs.timer.doAfter
     .2
     (fn []
       (if (= cur-app :Emacs)
           (do
             (windows.rect rect-left)
             (windows.jump-to-last-window)
             (windows.rect rect-right))
           (do
             (windows.rect rect-right)
             (hs.application.launchOrFocus :Emacs)
             (windows.rect rect-left)))))))

(fn switch-to-app [pid]
  "Don't remove! - this is callable from Emacs See: `spacehammer/switch-to-app`
   in spacehammer.el "
  (let [app (hs.application.applicationForPID pid)]
    (when app (: app :activate))))

(fn switch-to-app-and-paste-from-clipboard [pid]
  "Don't remove! - this is callable from Emacs See:
   `spacehammer/finish-edit-with-emacs` in spacehammer.el."
  (let [app (hs.application.applicationForPID pid)]
    (when app
      (: app :activate)
      (: app :selectMenuItem [:Edit :Paste]))))


(fn maximize
  []
  "Maximizes Emacs GUI window after a short delay."
  (hs.timer.doAfter
   1.5
   (fn []
     (let [app     (hs.application.find :Emacs)
           windows (require :windows)
           modal   (require :modal)]
       (when app
         (: app :activate)
         (windows.maximize-window-frame))))))

{:capture                          capture
 :edit-with-emacs                  edit-with-emacs
 :editWithEmacsCallback            edit-with-emacs-callback
 :full-screen                      full-screen
 :maximize                         maximize
 :note                             (fn [] (capture true))
 :switchToApp                      switch-to-app
 :switchToAppAndPasteFromClipboard switch-to-app-and-paste-from-clipboard
 :vertical-split-with-emacs        vertical-split-with-emacs}
