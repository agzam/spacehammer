
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

;; executes emacsclient, evaluating special function that must be present in
;; Emacs config, passing pid and title of the caller app, along with display id
;; where the screen of the caller app is residing
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

;; don't remove! - this is callable from Emacs
(fn edit-with-emacs-callback [pid title screen]
  (let [emacs-app (hs.application.get :Emacs)
        edit-window (: emacs-app :findWindow :edit)
        scr (hs.screen.find (tonumber screen))
        windows (require :windows)]
    (when (and edit-window scr)
      (: edit-window :moveToScreen scr)
      (: windows :center-window-frame))))

;; global keybinging to invoke edit-with-emacs feature
(local edit-with-emacs-key (hs.hotkey.new [:cmd :ctrl] :o nil edit-with-emacs))

(fn bind [hotkeyModal fsm]
  (: hotkeyModal :bind nil :c (fn []
                                (: fsm :toIdle)
                                (capture)))
  (: hotkeyModal :bind nil :z (fn []
                                (: fsm :toIdle)
                                ;; note on currently clocked in
                                (capture true))))

;; adds Emacs modal state to the FSM instance
(fn add-state [modal]
  (modal.add-state
   :emacs
   {:from :*
    :init (fn [self fsm]
            (set self.hotkeyModal (hs.hotkey.modal.new))
            (modal.display-modal-text "c \tcapture\nz\tnote")

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

(fn disable-edit-with-emacs []
  (: edit-with-emacs-key :disable))

(fn enable-edit-with-emacs []
  (: edit-with-emacs-key :enable))

(fn add-app-specific []
  (let [keybindings (require :keybindings)]
    (keybindings.add-app-specific
     :Emacs
     {:activated
      (fn []
        (keybindings.disable-simple-vi-mode)
        (disable-edit-with-emacs))
      :launched
      (fn []
        (hs.timer.doAfter 1.5
                          (fn []
                            (let [app (hs.application.find :Emacs)
                                  windows (require :windows)
                                  modal (require :modal)]
                              (when app
                                (: app :activate)
                                (windows.maximize-window-frame (: modal :machine)))))))})))

{:enable-edit-with-emacs                 enable-edit-with-emacs
 :disable-edit-with-emacs                disable-edit-with-emacs
 :add-state                              add-state
 :edit-with-emacs                        edit-with-emacs
 :switchToApp                            switch-to-app
 :switchToAppAndPasteFromClipboard       switch-to-app-and-paste-from-clipboard
 :editWithEmacsCallback                  edit-with-emacs-callback
 :add-app-specific                       add-app-specific}
