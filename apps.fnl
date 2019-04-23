(local windows (require :windows))
(local multimedia (require :multimedia))
(local slack (require :slack))

{:addState
 (fn [modal]
   (modal.addState :apps
    {:from :*
     :init (fn [self, fsm]
             (set self.hotkeyModal (hs.hotkey.modal.new))
             (modal.displayModalText
              "e\t emacs\ng \t chrome\n f\t Firefox\n i\t iTerm\n s\t slack\n b\t brave")

             (modal.bind
              self
              [:cmd] :space
              (fn [] (: fsm :toMain)))

             (slack.bind
              self.hotkeyModal fsm)

             (each [key app (pairs
                             {:i "iTerm2",
                              :g "Google Chrome",
                              :b "Brave",
                              :e "Emacs",
                              :f "Firefox",
                              :m multimedia.musicApp})]
               (modal.bind
                self nil key
                (fn []
                  (windows.activateApp app)
                  (: fsm :toIdle))))

             (: self.hotkeyModal :enter))}))}
