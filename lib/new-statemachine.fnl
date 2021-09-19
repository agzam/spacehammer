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
;;            :state3
;;                     ; TODO: Do we want :enter and :exit, or let the effects
;;                     ; callback handle it
;;                     {:leave :state2
;;                      :enter :state3}
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
  the all subscribers with the old state, new state, action, and extra"
  (log.wf "signal action :%s" action) ;; DELETEME
  (let [current-state (atom.deref fsm.current-state)
        next-state ((. fsm.states current-state action) fsm.context action extra)
        effect next-state.effect]
    ; If next-state is nil, error: Means the action is not expected in this state
    (log.wf "XXX Signal current: :%s next: :%s action: :%s extra: %s effect: :%s" (atom.deref fsm.current-state) (hs.inspect next-state) action extra effect) ;; DELETEME
    (if next-state
        (do
          (set-state fsm next-state)
          ; TODO: Should we let this callback decide on the new state? But there
          ; can be multiple listeners
          ; TODO: Provide whole FSM or just context?
          (each [_ sub (pairs (atom.deref fsm.subscribers))]
            (log.wf "Calling sub %s" sub) ;; DELETEME
                (sub {:prev-state current-state :next-state next-state :effect effect}))
          )
        (log.wf "Action :%s is not defined in state :%s" action current-state))))

(fn subscribe
  [fsm sub]
  "Adds a subscriber to the provided fsm. Returns a function to unsubscribe"
  ; Super naive: Returns a function that just removes the entry at the inserted
  ; key, but doesn't allow the same function to subscribe more than once since
  ; its keyed by the string of the function itself.
  (let [sub-key (tostring sub)]
    (log.wf "Adding subscriber %s" sub) ;; DELETEME
    (atom.swap! fsm.subscribers (fn [subs sub]
                                  (merge {sub-key sub} subs)) sub)
    ; Return the unsub func
    (fn []
      (atom.swap! fsm.subscribers (fn [subs key] (tset subs key nil)) sub-key))))

(fn create-machine
  [states initial-state]
  (merge {:current-state (atom.new initial-state)
          :context (atom.new states.context)
          ; TODO: Use something less naive for subscribers
          :subscribers (atom.new {})}
         states))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Example
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var modal-fsm nil)
(fn enter-menu
  [context menu]
  (log.wf "XXX Enter menu %s. Current stack: %s" menu (hs.inspect (atom.deref context.menu-stack))) ;; DELETEME
  (atom.swap! context.menu-stack (fn [stack menu] (conj stack menu)) menu)
  {:current-state :menu
   :context {:history []
             :menu :main-menu}
   :effect :modal-opened})

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
          (= action :open) (enter-menu context :main))
      (= old-state :menu)
      (if (= action :leave) (leave-menu context)
          (= action :back) (up-menu context extra)
          ; TODO: Which menu? Does enter-menu figure it out or do we?
          (= action :select) (enter-menu context extra))))


(local modal-states
       {:states {:idle {:leave :idle
                        :open (fn [context action extra]
                                {:current-state :menu
                                 :context {:history []
                                           :menu :main-menu}
                                 :effect :modal-opened})}
                 :menu {:leave leave-menu
                        :back up-menu
                        :select enter-menu}}
        :context {:modal {:modal nil
                          :stop-func nil}
                  ; TODO: This would be filled based on config
                  :menu-hierarchy nil
                  :menu-stack (atom.new [])}})

; This creates an atom for current-state and context
; TODO: We could require the initiali state me a key in the states map
; TODO: If we preserve the initial context we can maybe fsm.reset, thoug that's
; hard to do safely since it only restores state and context, not the state of
; hammerspoon itself, e.g. keys bindings, that have been messed with with all
; the signal handlers.
(set modal-fsm (create-machine modal-states :idle))
(local unsub-display (subscribe modal-fsm (fn [] (alert "MENU HERE"))))
(local unsub-bind (subscribe modal-fsm (fn [] (log.wf "Binding keys..."))))
(log.wf "Subs: %s" (hs.inspect (atom.deref modal-fsm.subscribers))) ;; DELETEME
;; (unsub) ;; DELETEME
;; (log.wf "Subs: %s" (hs.inspect (atom.deref modal-fsm.subscribers))) ;; DELETEME

; Debuging bindings
(hs.hotkey.bind [:cmd] :s (fn [] (log.wf "XXX Current stack: %s" (hs.inspect (atom.deref modal-fsm.context.menu-stack))))) ;; DELETEME

{: signal
 : modal-fsm  ;; DELETEME
 : subscribe
 :new create-machine}
