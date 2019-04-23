(local modal {})
(local utils (require "utils"))
(local statemachine (require "statemachine"))
(local windows (require "windows"))

(global states {})

(fn exit-all-modals [fsm]
  (each [k s (pairs states)]
    (when s.hotkeyModal
      (: s.hotkeyModal :exit))))

(fn display-modal-text [txt]
  (hs.alert.closeAll)
  (alert txt 999999))

(fn bind [modal mods key fun]
  (: modal.hotkeyModal :bind mods key fun))

(fn filter-allowed-apps [w]
  (if (: w :isStandard)
      true
      false))

(global states
 {:idle {:from :*
         :to :idle
         :callback (fn [self event from to]
                     (hs.alert.closeAll)
                     (exit-all-modals self))}
  :main {:from :*
         :to :main
         :init (fn [self, fsm]
                 (if self.hotkeyModal
                     (: self.hotkeyModal :enter)
                     (set self.hotkeyModal (hs.hotkey.modal.new [:cmd] :space)))

                 (bind
                  self nil :space
                  (fn []
                    (: fsm :toIdle)
                    (windows.activateApp "Alfred 3")))

                 (bind self nil :escape (fn [] (: fsm :toIdle)))
                 (bind self nil :q (fn [] (: fsm :toIdle)))
                 (bind self :ctrl :g (fn [] (: fsm :toIdle)))

                 (bind self nil :w (fn [] (: fsm :toWindows)))
                 (bind self nil :a (fn [] (: fsm :toApps)))
                 (bind self nil :m (fn [] (: fsm :toMedia)))
                 (bind self nil :x (fn [] (: fsm :toEmacs)))

                 (bind self nil :j (fn []
                                     (let [wns (hs.fnutils.filter (hs.window.allWindows) filter-allowed-apps)]
                                       (hs.hints.windowHints wns nil true)
                                       (: fsm :toIdle))))

                 (fn self.hotkeyModal.entered []
                   (display-modal-text "w \t- windows\na \t- apps\n j \t- jump\nm - media\nx\t- emacs")))}})

(fn create-machine []
  (let [events {}
        callbacks {}]
    (each [k s (pairs states)]
      (table.insert events {:name (.. :to (utils.capitalize k))
                            :from (or s.from {:main :idle})
                            :to (or s.to k)}))
    (each [k s (pairs states)]
      (tset
       callbacks (.. "on" k)
       (or s.callback
           (fn [self event from to]
             (let [st (. states to)]
               (st.init st self))))))

    (statemachine.create
     {:initial :idle
      :events events
      :callbacks callbacks})))

(fn add-state [name state]
  (tset states name state))

{:createMachine create-machine
 :addState add-state
 :displayModalText display-modal-text
 :bind bind
 :states states}
