(local atom (require :lib.atom))
(local {: butlast
        : concat
        : conj
        : merge
        : slice} (require :lib.functional))

(local log (hs.logger.new "\tstatemachine.fnl\t" "debug"))

;;
;; Schema
;; { :current-state ; An atom keyword
;;   :states {:state1 {}
;;            :state2 {}
;;            :state3 {
;;                     ; TODO: Do we want :enter and :exit, or let the effects
;;                     ; callback handle it
;;                     :transitions {:leave :state2
;;                                   :enter :state3}
;;            :state4 {}
;;                     }}}
;;   :transitions} ; takes in fsm & event
;;   ; TODO: Could this :context be completely separate from the FSM? Since only
;;   ; `effects` callbacks should touch it. How it is provided to them, though?'
;;   :context ; an atom that tracks extra data e.g. current app, history, etc.
;;
(fn set-state
  [fsm state]
  (atom.swap! fsm.current-state (fn [_ state] state) state))

(fn signal
  [fsm action extra]
  "Based on the action and the fsm's current-state, set the new state and call
  the effects listener with the old state, new state, action, and extra"
  (let [current-state (atom.deref fsm.current-state)
        next-state (. fsm.states current-state :transitions action)
        effects fsm.effects]
    ; If next-state is nil, error: Means the action is not expected in this state
    (log.wf "XXX Signal current: :%s next: :%s action: :%s extra: %s" (atom.deref fsm.current-state) next-state action extra) ;; DELETEME
    (if next-state
        (do
          (set-state fsm next-state)
          ; TODO: Should we let this callback decide on the new state? But there
          ; can be multiple listeners
          ; TODO: Provide whole FSM or just context?
          (effects fsm.context current-state next-state action extra))
        (log.wf "Action :%s is not defined in state :%s" action current-state))))

(fn create-machine
  [states initial-state]
  (merge {:current-state (atom.new initial-state)
          :context (atom.new states.context)}
         states))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Example
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var modal-fsm nil)
(fn enter-menu
  [context menu]
  (log.wf "XXX Enter menu %s. Current stack: %s" menu (hs.inspect (atom.deref context.menu-stack))) ;; DELETEME
  ; TODO: Show the actual menu
  ; TODO: Bind keys according to actual menu
  (alert "menu")
  (atom.swap! context.menu-stack (fn [stack menu] (conj stack menu)) menu)
  (hs.hotkey.bind [:cmd] "l" (fn [] (signal modal-fsm :leave)))
  ; Down a menu deeper
  (hs.hotkey.bind [:cmd] "d"
                  (fn [] (signal modal-fsm :select (tostring (length (atom.deref context.menu-stack))))))
  ; Up a menu
  (hs.hotkey.bind [:cmd] "u" (fn [] (signal modal-fsm :back))))

(fn up-menu
  [context menu]
  "Go up a menu in the stack. If we are the last menu, then we must fire an
  event to :leave"
  (log.wf "XXX Up menu. Current stack: %s" (hs.inspect (atom.deref context.menu-stack))) ;; DELETEME
  ; TODO: Unbind keys from this menu
  (let [stack (atom.deref (atom.swap! context.menu-stack (fn [stack] (butlast stack))))]
    (when (= (length stack) 0) (signal modal-fsm :leave))))

(fn leave-menu
  [context]
  (log.wf "XXX Leave menu") ;; DELETEME
  (log.wf "XXX Leave menu. Current stack: %s" (hs.inspect (atom.deref context.menu-stack))) ;; DELETEME
  ; TODO: Unbind keys from this menu
  (atom.swap! context.menu-stack (fn [_ menu] []))
  )

(fn modal-action
  ; 'extra' would be the key hit, or name of the action, so we know which
  ; submenu to enter, for example. A menu with 4 options would bind each to a
  ; function calling (signal :enter), but each with their own 'extra'. Maybe the
  ; key hit or the menu itself
  [context old-state new-state action extra]
  (log.wf "XXX Got action :%s with extra %s while in :%s, transitioning to :%s" action extra old-state new-state) ;; DELETEME
  (if (=  old-state :idle)
      (if (= action :leave) nil
          (= action :activate) (enter-menu context :main))
      (= old-state :menu)
      (if (= action :leave) (leave-menu context)
          (= action :back) (up-menu context extra)
          ; TODO: Which menu? Does enter-menu figure it out or do we?
          (= action :select) (enter-menu context extra))))


(local modal-states
       {:states {:idle {:enter nil
                        :exit nil
                        :transitions {:leave :idle
                                      :activate :menu}}
                 :menu {:enter nil
                        :exit nil
                        ; TODO: How can we allow a transition to a previous menu
                        :transitions {
                                      ; Leave dumps all menus
                                      :leave :idle
                                      ; Back pops a menu off the stack
                                      :back :menu
                                      ; Select pushes a menu on the stack
                                      :select :menu}}}
        ; TODO: This would be an event stream dispatcher or publish func
        :effects modal-action
        :context {:modal {:modal nil
                          :stop-func nil}
                  ; TODO: This would be filled based on config
                  :menu-hierarchy nil
                  :menu-stack (atom.new [])}})

; This creates an atom for current-state and context
(set modal-fsm (create-machine modal-states :idle))

; Debuging bindings
(hs.hotkey.bind [:cmd] :s (fn [] (log.wf "XXX Current stack: %s" (hs.inspect (atom.deref modal-fsm.context.menu-stack))))) ;; DELETEME

{: signal
 :modal-fsm modal-fsm  ;; DELETEME
 :new create-machine}
