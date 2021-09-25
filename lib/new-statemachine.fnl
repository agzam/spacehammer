(local atom (require :lib.atom))
(local {: butlast
        : call-when
        : concat
        : conj
        : last
        : merge
        : slice} (require :lib.functional))

(local log (hs.logger.new "\tstatemachine.fnl\t" "debug"))

;; Finite state machine
;; Template schema
;; {
;;  ; The state is converted to an atom in the contructor
;;  :state {:current-state :state1
;;          :context {}}
;;  ; States table: A map of state names to a map of actions to functions
;;  ; These functions must return a map containing the new state keyword, the
;;  ; effect, and a new context
;;  :states {:state1 {}
;;           :state2 {}
;;           :state3 {:leave state3-leave
;;                    :exit state3-exit}}}

; TODO: Handle a signal with no handler for the provided action. E.g. if a state
; has a keyword instead of a function should we just create a new state from the
; old one, setting the new current-state to the key? This would allow simple
; transitions that don't change context, but still allow subscribers a chance to
; run (though the 'effect' will be nil)

; TODO: Convert to method
(fn update-state
  [fsm state]
  (atom.swap! fsm.state (fn [_ state] state) state))

; TODO: Convert to method
(fn get-state
  [fsm]
  (atom.deref fsm.state))

; TODO: Convert to method
(fn signal
  [fsm action extra]
  "Based on the action and the fsm's current-state, set the new state and call
  all subscribers with the previous state, new state, action, and extra"
  (let [state (atom.deref fsm.state)
        {: current-state : context} state
        _ (log.wf "XXX Current state: %s" current-state) ;; DELETEME
        tx-fn (. fsm.states current-state action)
        ; TODO: Should we pass the whole state (current state and context) or just context?
        transition (tx-fn state action extra)
        ;; _ (log.wf "XXX received transition info:\n%s" (hs.inspect transition)) ;; DELETEME
        new-state transition.state
        _ (log.wf "XXX next state: %s" new-state.current-state) ;; DELETEME
        _ (log.wf "XXX new context: %s" (hs.inspect new-state.context)) ;; DELETEME
        effect transition.effect]
    ; If next-state is nil, error: Means the action is not expected in this state
    (log.wf "XXX Signal current: :%s next: :%s action: :%s extra: %s effect: :%s" current-state new-state.current-state action extra effect) ;; DELETEME

    (update-state fsm new-state)
    ; Call all subscribers
    (log.wf "XXX BLA %s" (hs.inspect {:prev-state state :next-state new-state : effect : extra}))
    (each [_ sub (pairs (atom.deref fsm.subscribers))]
      (sub {:prev-state state :next-state new-state : action : effect : extra}))))

; TODO: Convert to method
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

(fn effect-handler
  [effect-map]
  "
  Takes a map of effect->function and returns a function that handles these
  effects by calling the mapped-to function, and then calls that function's
  return value (a cleanup function) and calls it on the next transition.

  These functions must return their own cleanup function or nil.
  "
  ;; Create a one-time atom used to store the cleanup function
  (let [cleanup-ref (atom.new nil)]
    ;; Return a subscriber function
    (fn [{: prev-state : next-state : action : effect : extra}]
      (log.wf "Effect handler called") ;; DELETEME
      ;; Whenever a transition occurs, call the cleanup function, if set
      (call-when (atom.deref cleanup-ref))
      ;; Get a new cleanup function or nil and update cleanup-ref atom
      (atom.reset! cleanup-ref
                   ; TODO: Should we provide everything e.g. prev-state, action, effect?
                   (call-when (. effect-map effect) next-state extra)))))

(fn create-machine
  [template]
  {:state (atom.new {:current-state template.state.current-state :context template.state.context})
   :states template.states
   ; TODO: Use something less naive for subscribers
   :subscribers (atom.new {})})

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Example
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var modal-fsm nil)

;; Transition functions
(fn enter-menu
  [state action extra]
  (log.wf "XXX Enter menu action: %s. Current stack: %s" action (hs.inspect state.context.menu-stack)) ;; DELETEME
  {:state {:current-state :menu
           :context (merge state.context {:menu-stack (conj state.context.menu-stack extra)
                                          :current-menu :main})}
   :effect :modal-opened})

(fn up-menu
  [state action extra]
  "Go up a menu in the stack."
  (log.wf "XXX Up menu. Current stack: %s" (hs.inspect state.context.menu-stack)) ;; DELETEME
  ; Pop the menu off the stack & calculate new state transition
  (let [stack (butlast state.context.menu-stack)
        depth (length stack)
        target-state (if (= 0 depth) :idle :menu)
        target-effect (if (= :idle target-state) :modal-closed :modal-opened)
        new-menu (last stack)]
    {:state {:current-state target-state
             :context (merge state.context {:menu-stack stack
                                            :current-menu new-menu})}
     :effect target-effect}) )

(fn leave-menu
  [state action extra]
  (log.wf "XXX Leave menu. Current stack: %s" (hs.inspect state.context.menu-stack)) ;; DELETEME
  {:state {:current-state :idle
           :context (merge state.context {:menu-stack state.context.menu-stack
                                          :menu :main-menu})}
   :effect :modal-closed})

;; State machine
(local modal-states
       {:state {:current-state :idle
                :context {
                  ; This would be structured based on config in the modal module
                  :menu-hierarchy {:a {}
                                   :b {}
                                   :c {}}
                  :current-menu :nil
                  :menu-stack []}}
        :states {:idle {:leave :idle
                        :open enter-menu}
                 :menu {:leave leave-menu
                        :back up-menu
                        :select enter-menu}}})


;; Effect handlers
(fn modal-opened-menu-handler
  [state extra]
  (log.wf "Modal opened menu handler called")
  (alert (string.format "MENU %s" extra))
  ;; Return a cleanup func
  (fn [] (log.wf "Modal opened menu handler CLEANUP called")))

(fn modal-closed-menu-handler
  [state extra]
  (log.wf "Modal closed menu handler called")
  (alert (string.format "MENU %s" extra))
  ;; Return a cleanup func
  (fn [] (log.wf "Modal closed menu handler CLEANUP called")))

(fn modal-opened-key-handler
  [state extra]
  (log.wf "Modal opened key handler called")
  ; TODO: Make this consider keys relative to its position in the hierarchy
  (if (. state :context :menu-hierarchy extra)
      (log.wf "Key in hierarchy")
      (log.wf "Key NOT in hierarchy"))
  ;; Return a cleanup func
  (fn [] (log.wf "Modal opened key handler CLEANUP called")))

; Create FSM
(set modal-fsm (create-machine modal-states))

; Add subscribers
(local unsub-menu-sub
       (subscribe modal-fsm (effect-handler {:modal-opened modal-opened-menu-handler
                                             :modal-closed modal-closed-menu-handler})))
(local unsub-key-sub
       (subscribe modal-fsm (effect-handler {:modal-opened modal-opened-key-handler})))
(log.wf "FSM: %s" (hs.inspect modal-fsm)) ;; DELETEME
(log.wf "Subs: %s" (hs.inspect (atom.deref modal-fsm.subscribers))) ;; DELETEME
(log.wf "State: %s" (hs.inspect (get-state modal-fsm))) ;; DELETEME

; Debuging bindings. Call it in config.fnl so the bindings aren't not trampled
(fn bind []
  (hs.hotkey.bind [:alt :cmd :ctrl] :v
                  (fn []
                    (log.wf "XXX Current stack: %s"
                            (hs.inspect (. (atom.deref modal-fsm.state) :context :menu-stack)))))
  (hs.hotkey.bind [:cmd] :o (fn [] (signal modal-fsm :open :main)))
  (hs.hotkey.bind [:cmd] :u (fn [] (signal modal-fsm :back nil)))
  (hs.hotkey.bind [:cmd] :l (fn [] (signal modal-fsm :leave nil)))
  (hs.hotkey.bind [:cmd] :a (fn [] (signal modal-fsm :select :a)))
  (hs.hotkey.bind [:cmd] :r (fn [] (signal modal-fsm :select :b)))
  (hs.hotkey.bind [:cmd] :s (fn [] (signal modal-fsm :select :c))))

{: signal
 : bind    ;; DELETEME
 : modal-fsm ;; DELETEME
 : subscribe
 :new create-machine}
