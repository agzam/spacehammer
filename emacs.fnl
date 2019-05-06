
(fn capture [is-note]
  (let [key (if is-note "\"z\"" "")
        current-app (hs.window.focusedWindow)
        pid (.. "\"" (: current-app :pid) "\" ")
        title (.. "\"" (: current-app :title) "\" ")
        run-str  (..
                  "/usr/local/bin/emacsclient"
                  " -c -F '(quote (name . \"capture\"))'"
                  " -e '(activate-capture-frame "
                  pid title key " )'")
        timer (hs.timer.delayed.new .1 (fn [] (io.popen run-str)))]
    (: timer :start)))

(fn edit-with-emacs []
  (let [current-app (: (hs.window.focusedWindow) :application)
        pid (.. "\"" (: current-app :pid) "\"")
        title (.. "\"" (: current-app :title) "\"")
        screen (.. "\"" (: (hs.screen.mainScreen) :id) "\"")
        run-str (..
                 "/usr/local/bin/emacsclient"
                 " -c -F '(quote (name . \"edit\"))' "
                 " -e '(ag/edit-with-emacs "
                 pid " " title " " screen " )'")]
    ;; select all + copy
    (hs.eventtap.keyStroke [:cmd] :a)
    (hs.eventtap.keyStroke [:cmd] :c)
    (io.popen run-str)))

(fn edit-with-emacs-callback [pid title screen]
  (let [emacs-app (hs.application.get :Emacs)
        edit-window (: emacs-app :findWindow :edit)
        scr (hs.screen.find (tonumber screen))
        windows (require :windows)]
    (when (and edit-window scr)
      (: edit-window :moveToScreen scr)
      (: windows :centerWindowFrame))))

(local edit-with-emacs-key (hs.hotkey.new [:cmd :ctrl] :o nil edit-with-emacs))

(fn bind [hotkeyModal fsm]
  (: hotkeyModal :bind nil :c (fn []
                                (: fsm :toIdle)
                                (capture)))
  (: hotkeyModal :bind nil :z (fn []
                                (: fsm :toIdle)
                                ;; note on currently clocked in
                                (capture true))))

(fn add-state [modal]
  (modal.addState
   :emacs
   {:from :*
    :init (fn [self fsm]
            (set self.hotkeyModal (hs.hotkey.modal.new))
            (modal.displayModalText "c \tcapture\nz\tnote")

            (bind self.hotkeyModal fsm)
            (: self.hotkeyModal :enter))}))


;; don't remove! - this is callable from Emacs
(fn switch-to-app [pid]
  (let [app (hs.application.applicationForPID pid)]
    (when app (: app :activate))))

;; don't remove! - this is callable from Emacs
(fn switch-to-app-and-paste-from-clipboard [pid]
  (let [app (hs.application.applicationForPID pid)]
    (when app
      (: app :activate)
      (: app :selectMenuItem [:Edit :Paste]))))

{:enableEditWithEmacs (fn [] (: edit-with-emacs-key :enable))
 :disableEditWithEmacs (fn [] (: edit-with-emacs-key :disable))
 :addState add-state
 :switchToApp switch-to-app
 :switchToAppAndPasteFromClipboard switch-to-app-and-paste-from-clipboard
 :editWithEmacsCallback edit-with-emacs-callback}
