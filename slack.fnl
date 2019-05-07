(local keybindings (require :keybindings))
(local windows (require :windows))

(local slack-local-hotkeys
       [;; jump to end of thread on C-g
        (hs.hotkey.bind [:alt] :g (fn [] (alert "alt g in slack yo")))

        ;; add a reaction
        (hs.hotkey.bind [:alt] :r (fn [] (hs.eventtap.keyStroke [:cmd :shift] "\\")))

        ;; TODO: start a thread
        ])


;; Slack client doesn't allow convenient method to scrolling in thread with keyboard
;; adding C-e, C-y bindings for scrolling up and down
(each [k dir (pairs {:e -3 :y 3})]
  (let [scroll-fn (fn []
                    (windows.set-mouse-cursor-at :Slack)
                    (hs.eventtap.scrollWheel [0 dir] {}))]
    (table.insert slack-local-hotkeys (hs.hotkey.new [:ctrl] k scroll-fn nil scroll-fn))))


;; Alt-o|Alt-i to go back and forth in history
(each [k dir (pairs {:o "[" :i "]"})]
  (let [back-fwd (fn [] (hs.eventtap.keyStroke [:cmd] dir))]
    (table.insert slack-local-hotkeys (hs.hotkey.new [:alt] k back-fwd nil back-fwd))))


;; C-n|C-p - for up and down (instead of using arrow keys)
(each [k dir (pairs {:p :up :n :down})]
  (let [up-n-down (fn [] (hs.eventtap.keyStroke nil dir))]
    (table.insert slack-local-hotkeys (hs.hotkey.new [:ctrl] k up-n-down nil up-n-down))))

(tset
 keybindings.app-specific :Slack
 {:activated (fn []
               (hs.fnutils.each slack-local-hotkeys
                                (partial keybindings.activate-app-key :Slack)))
  :deactivated (fn [] (keybindings.deactivate-app-keys :Slack))})

(fn bind [modal fsm]

  ;; open "Jump to dialog immediately after jumping to Slack GUI through `Apps` modal"
  (: modal :bind nil :s
     (fn []
       (hs.application.launchOrFocus "/Applications/Slack.app")
       (let [app (hs.application.find :Slack)]
         (when app
           (: app :activate)
           (hs.timer.doAfter .2 windows.highlight-active-window)
           (hs.eventtap.keyStroke [:cmd] :t)
           (: app :unhide))
         (: fsm :toIdle)))))


{:bind bind}
