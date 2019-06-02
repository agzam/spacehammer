(local modal {})
(local utils (require :utils))
(local statemachine (require :statemachine))
(local windows (require :windows))
(local keybindings (require :keybindings))

(global states {})

(fn exit-all-modals [fsm]
  (each [k s (pairs states)]
    (when s.hotkeyModal
      (: s.hotkeyModal :exit)))
  (each [_ m (pairs states.applocal.modals)]
    (when m (: m :exit))))

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
         :init (fn [self fsm]
                 (if self.hotkeyModal
                     (: self.hotkeyModal :enter)
                     (set self.hotkeyModal (hs.hotkey.modal.new [:cmd] :space)))

                 (bind
                  self nil :space
                  (fn []
                    (: fsm :toIdle)
                    (windows.activate-app "Alfred 4")))

                 (bind self nil :escape (fn [] (: fsm :toIdle)))
                 (bind self nil :q (fn [] (: fsm :toIdle)))
                 (bind self :ctrl :g (fn [] (: fsm :toIdle)))

                 (bind self nil :w (fn [] (: fsm :toWindows)))
                 (bind self nil :a (fn [] (: fsm :toApps)))
                 (bind self nil :m (fn [] (: fsm :toMedia)))
                 (bind self nil :x (fn [] (: fsm :toEmacs)))

                 ;; jump to any app with :j
                 (bind self nil :j (fn []
                                     (let [wns (hs.fnutils.filter (hs.window.allWindows) filter-allowed-apps)]
                                       (hs.hints.windowHints wns nil true)
                                       (: fsm :toIdle))))

                 (fn self.hotkeyModal.entered []
                   (display-modal-text "w \t- windows\na \t- apps\n j \t- jump\nm - media\nx\t- emacs")))}

  ;; `:applocal` is a state that gets activated whenever user would switch to an
  ;; app that allows localized modals. Localized modals are enabled by adding
  ;; `:app-local-modal' key in `keybindings.app-specific'
  :applocal {:from :*
             :modals []
             :init (fn [self fsm]
                     (set self.toIdle (fn [] (: fsm :toIdle)))
                     ;; - read `keybindings.app-specific`
                     ;; - find a key matching with current app-name
                     ;; - if has `:app-local-modal' key, activate the modal
                     (let [cur-app (-?> (hs.window.focusedWindow) (: :application) (: :name))
                           fnd (-?> keybindings.app-specific (. cur-app) (. :app-local-modal))
                           mdl (fn [] (. self.modals cur-app))]
                       (when fnd
                         (when (not (mdl))
                           (tset self.modals cur-app (hs.hotkey.modal.new)))
                         (fnd (mdl) fsm)
                         (: (mdl) :enter))))}})

;; stores instance of finite-state-machine.
;; Externally accessible via `modal.machine()'
(global machine nil)

;; creates instance of finite-state-machine based on `modal.states`. Other
;; modules can add more states using `modal.add-state`, but then `create-machine'
;; has to run after it again
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

    (let [fsm (statemachine.create
               {:initial :idle
                :events events
                :callbacks callbacks})]
      (global machine fsm)
      machine)))

(fn add-state [name state]
  (tset states name state))

{:create-machine     create-machine
 :add-state          add-state
 :display-modal-text display-modal-text
 :bind               bind
 :states             states
 :machine            (fn [] machine)}
