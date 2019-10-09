(local windows (require :windows))
(local multimedia (require :multimedia))
(local slack (require :slack))

(fn add-state [modal]
  (modal.add-state
   :apps
   {:from :*
    :init (fn [self fsm]
            (set self.hotkeyModal (hs.hotkey.modal.new))
            (modal.display-modal-text
             "e\t emacs\ng \t chrome\n f\t Firefox\n i\t iTerm\n s\t slack\n b\t brave")

            (modal.bind
             self
             [:cmd] :space
             (fn [] (: fsm :toMain)))

            (slack.bind self.hotkeyModal fsm)

            (each [key app (pairs
                            {:i "iTerm2"
                             :g "Google Chrome"
                             :b "Brave"
                             :e "Emacs"
                             :f "Firefox"
                             :m multimedia.music-app})]
              (modal.bind
               self nil key
               (fn []
                 (: fsm :toIdle)
                 (windows.activate-app app))))

            (: self.hotkeyModal :enter))}))

{:add-state add-state}
