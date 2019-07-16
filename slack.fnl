(local keybindings (require :keybindings))
(local windows (require :windows))

(local
 slack-local-hotkeys
 [;; jump to end of thread on Cmd-g
  (hs.hotkey.bind
   [:cmd] :g
   (fn []
     (windows.set-mouse-cursor-at :Slack)
     ;; this number should be big enough to take you
     ;; to the bottom of the chat window
     (hs.eventtap.scrollWheel [0 -20000] {})))

  ;; add a reaction
  (hs.hotkey.bind [:ctrl] :r (fn [] (hs.eventtap.keyStroke [:cmd :shift] "\\")))

  ;; F6 mode
  (hs.hotkey.bind [:ctrl] :h (fn [] (hs.eventtap.keyStroke [:shift] :f6)))
  (hs.hotkey.bind [:ctrl] :l (fn [] (hs.eventtap.keyStroke [] :f6)))

  ;; Start a thread on the last message. It doesn't always work, because of
  ;; stupid Slack App inconsistency with TabIndexes
  (hs.hotkey.bind
   [:ctrl] :t
   (fn []
     (hs.eventtap.keyStroke [:shift] :f6)
     (hs.eventtap.keyStroke [] :right)
     (hs.eventtap.keyStroke [] :space)))

  ;; scroll to prev/next day
  (hs.hotkey.bind [:ctrl] "[" (fn [] (hs.eventtap.keyStroke [:shift] :pageup)))
  (hs.hotkey.bind [:ctrl] "]" (fn [] (hs.eventtap.keyStroke [:shift] :pagedown)))])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; when connected to given WiFi network change Slack status ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(local
 ssids->status
 {:Vachach {:text :WFH :emoji ":house:"}
  :Vachach5 {:text :WFH :emoji ":house:"}
  :DFNet-SF {:text "" :emoji ""}})

(fn send-slack-request
  [text emoji auth-token callback]
  (hs.http.asyncPost
   "https://slack.com/api/users.profile.set"
   (hs.json.encode
    {:profile {:status_text text
               :status_emoji emoji
               :status_expiration 0}})
   {"Authorization" auth-token
    "Content-type" "application/json; charset=utf-8"}
   (fn [_ resp]
     (let [res (-> resp hs.json.decode (. :ok))]
       (when res (callback))))))

(fn change-slack-status [ssid]
  (let [st (. ssids->status ssid)
        secrets (require :secrets)]
    (when st
      (let [txt (. st :text)
            emoji (. st :emoji)
            token (. (secrets.read) :slack-auth-token)]
        (send-slack-request
         txt emoji token
         (fn [] (hs.alert (.. "Setting Slack status to " txt))))))))

(global
 slack-wifi-watcher
 (or slack-wifi-watcher
     (->
      (hs.wifi.watcher.new
       (fn [_ _ interface]
         (hs.timer.doAfter
          5
          (fn []
            (change-slack-status (hs.wifi.currentNetwork interface))))))
      (: :watchingFor [:SSIDChange])
      (: :start))))


;; Slack client doesn't allow convenient method to scrolling in thread with keyboard
;; adding C-e, C-y bindings for scrolling up and down
(each [k dir (pairs {:e -3 :y 3})]
  (let [scroll-fn (fn []
                    (windows.set-mouse-cursor-at :Slack)
                    (hs.eventtap.scrollWheel [0 dir] {}))]
    (table.insert slack-local-hotkeys (hs.hotkey.new [:ctrl] k scroll-fn nil scroll-fn))))


;; Ctrl-o|Ctrl-i to go back and forth in history
(each [k dir (pairs {:o "[" :i "]"})]
  (let [back-fwd (fn [] (hs.eventtap.keyStroke [:cmd] dir))]
    (table.insert slack-local-hotkeys (hs.hotkey.new [:ctrl] k back-fwd nil back-fwd))))


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
