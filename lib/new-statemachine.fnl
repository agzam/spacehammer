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
;; Schema
;; {
;;  ; An atom keyword
;;  :current-state :state1
;;  ; States table: A map of state names to a map of actions to functions
;;  ; These functions must return a map containing the new state keyword, the
;;  ; effect, and a new context
;;  :states {:state1 {}
;;           :state2 {}
;;           :state3 {:leave state3-leave
;;                    :exit state3-exit}}
;;  ; An atom table
;;  :context {}}


(fn set-current-state
  [fsm state]
  (atom.swap! fsm.current-state (fn [_ state] state) state))

(fn set-context
  [fsm context]
  (atom.swap! fsm.context (fn [_ context] context) context))

(fn signal
  [fsm action extra]
  "Based on the action and the fsm's current-state, set the new state and call
  all subscribers with the old state, new state, action, and extra"
  (let [current-state (atom.deref fsm.current-state)
        _ (log.wf "XXX Current state: %s" current-state) ;; DELETEME
        context (atom.deref fsm.context)
        tx-fn (. fsm.states current-state action)
        ; TODO: Better name? This is the map that contains old, new, effect, etc.
        ; TODO: Handle a signal with no handler
        transition (tx-fn context action extra)
        ;; _ (log.wf "XXX received transition info:\n%s" (hs.inspect transition)) ;; DELETEME
        next-state transition.current-state
        _ (log.wf "XXX next state: %s" next-state) ;; DELETEME
        new-context transition.context
        ;; _ (log.wf "XXX new context: %s" (hs.inspect new-context)) ;; DELETEME
        effect transition.effect]
    ; If next-state is nil, error: Means the action is not expected in this state
    (log.wf "XXX Signal current: :%s next: :%s action: :%s extra: %s effect: :%s" current-state next-state action extra effect) ;; DELETEME

    (set-current-state fsm next-state)
    (set-context fsm new-context)
    ; Call all subscribers
    (each [_ sub (pairs (atom.deref fsm.subscribers))]
      (sub {:context new-context :prev-state current-state :next-state next-state :effect effect :extra extra}))))

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
    (fn [{: context : prev-state : next-state : effect : action : extra}]
      (log.wf "Effect handler called") ;; DELETEME
      ;; Whenever a transition occurs, call the cleanup function, if set
      (call-when (atom.deref cleanup-ref))
      ;; Get a new cleanup function or nil and update cleanup-ref atom
      (atom.reset! cleanup-ref
                   (call-when (. effect-map effect) context extra)))))

; TODO: We could require the initial state be a key in the states map
; TODO: If we preserve the initial context we can maybe fsm.reset, though that's
; hard to do safely since it only restores state and context, not the state of
; hammerspoon itself, e.g. keys bindings, that have been messed with with all
; the signal handlers.
(fn create-machine
  [states initial-state]
  {:current-state (atom.new initial-state)
   :context (atom.new states.context)
   :states states.states
   ; TODO: Use something less naive for subscribers
   :subscribers (atom.new {})})

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Example
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var modal-fsm nil)
(fn enter-menu
  [context action extra]
  (log.wf "XXX Enter menu action: %s. Current stack: %s" action (hs.inspect context.menu-stack)) ;; DELETEME
  {:current-state :menu
   :context (merge context {:menu-stack (conj context.menu-stack extra)
                            :current-menu :main})
   :effect :modal-opened})

(fn up-menu
  [context action extra]
  "Go up a menu in the stack."
  (log.wf "XXX Up menu. Current stack: %s" (hs.inspect context.menu-stack)) ;; DELETEME
  ; Pop the menu off the stack & calculate new state transition
  (let [stack (butlast context.menu-stack)
        depth (length stack)
        target-state (if (= 0 depth) :idle :menu)
        target-effect (if (= :idle target-state) :modal-closed :modal-opened)
        new-menu (last stack)]
    {:current-state target-state
     :context (merge context {:menu-stack stack
                              :current-menu new-menu})
     :effect target-effect}) )

(fn leave-menu
  [context action extra]
  (log.wf "XXX Leave menu. Current stack: %s" (hs.inspect context.menu-stack)) ;; DELETEME
  {:current-state :idle
   :context (merge context {:menu-stack context.menu-stack
                            :menu :main-menu})
   :effect :modal-closed})

(local modal-states
       {:states {:idle {:leave :idle
                        :open enter-menu}
                 :menu {:leave leave-menu
                        :back up-menu
                        :select enter-menu}}
        :context {
                  ; This would be structured based on config in the modal module
                  :menu-hierarchy {:a {}
                                   :b {}
                                   :c {}}
                  :current-menu nil
                  :menu-stack []}})

(fn modal-opened-menu-handler
  [context extra]
  (log.wf "Modal opened menu handler called")
  (alert (string.format "MENU %s" extra))
  ;; Return a cleanup func
  (fn [] (log.wf "Modal opened menu handler CLEANUP called")))

(fn modal-closed-menu-handler
  [context extra]
  (log.wf "Modal closed menu handler called")
  (alert (string.format "MENU %s" extra))
  ;; Return a cleanup func
  (fn [] (log.wf "Modal closed menu handler CLEANUP called")))

(fn modal-opened-key-handler
  [context extra]
  (log.wf "Modal opened key handler called")
  ; TODO: Make this consider keys relative to its position in the hierarchy
  (if (. context :menu-hierarchy extra)
      (log.wf "Key in hierarchy")
      (log.wf "Key NOT in hierarchy"))
  ;; Return a cleanup func
  (fn [] (log.wf "Modal opened key handler CLEANUP called")))

; Create FSM
(set modal-fsm (create-machine modal-states :idle))

; Add subscribers
(local unsub-menu-sub
       (subscribe modal-fsm (effect-handler {:modal-opened modal-opened-menu-handler
                                             :modal-closed modal-closed-menu-handler})))
(local unsub-key-sub
       (subscribe modal-fsm (effect-handler {:modal-opened modal-opened-key-handler})))
(log.wf "FSM: %s" (hs.inspect modal-fsm)) ;; DELETEME
(log.wf "Subs: %s" (hs.inspect (atom.deref modal-fsm.subscribers))) ;; DELETEME

; Debuging bindings. Call it in config.fnl so the bindings aren't not trampled
(fn bind []
  (hs.hotkey.bind [:alt :cmd :ctrl] :v
                  (fn []
                    (log.wf "XXX Current stack: %s"
                            (hs.inspect (. (atom.deref modal-fsm.context) :menu-stack)))))
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
