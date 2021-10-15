(local is (require :lib.testing.assert))
(local statemachine (require :lib.statemachine))
(local atom (require :lib.atom))

(fn make-fsm
  []
  (statemachine.new
   ;; States that the machine can be in mapped to their actions and transitions
   {:state   {:current-state :closed
              :context {:i     0
                        :event nil}}

    :states {:closed {:toggle (fn closed->opened
                                [state action extra]
                                {:state {:current-state :opened
                                         :context {:i (+ state.context.i 1)}}
                                 :effect :opening})}
             :opened {:toggle (fn opened->closed
                                [state action extra]
                                {:state {:current-state :closed
                                         :context {:i (+ state.context.i 1)}}
                                 :effect :closing})}}}))

(describe
 "State Machine"
 (fn []

   (it "Should create a new fsm in the closed state"
       (fn []
         (let [fsm (make-fsm)]
           (is.eq? (. (atom.deref fsm.state) :current-state) :closed "Initial state was not closed"))))

   (it "Should include some methods"
       (fn []
         (let [fsm (make-fsm)]
           (is.eq? (type fsm.get-state) :function "No get-state method")
           (is.eq? (type fsm.send) :function "No send method ")
           (is.eq? (type fsm.subscribe) :function "No subscribe method"))))

   (it "Should transition to opened on toggle action"
       (fn []
         (let [fsm (make-fsm)]
           (is.eq? (fsm.send :toggle) true "Dispatch did not return true for handled event")
           (is.eq? (. (atom.deref fsm.state) :current-state) :opened "State did not transition to opened"))))

   (it "Should transition from closed -> opened -> closed"
       (fn []
         (let [fsm (make-fsm)]
           (fsm.send :toggle)
           (fsm.send :toggle)
           (is.eq? (. (atom.deref fsm.state) :current-state) :closed "State did not transition back to closed")
           (is.eq? (. (atom.deref fsm.state) :context :i) 2  "context.i should be 2 from 2 transitions"))))

   (it "Should not explode when dispatching an unhandled event"
       (fn []
         (let [fsm (make-fsm)]
           (is.eq? (fsm.send :fail nil) false "The FSM exploded from dispatching a :fail event"))))

   (it "Subscribers should be called on events"
       (fn []
         (let [fsm (make-fsm)
               i (atom.new 0)]
           (fsm.subscribe (fn [] (atom.swap! i (fn [v] (+ v 1)))))
           (fsm.send :toggle)
           (is.eq? (atom.deref i) 1 "The subscriber was not called"))))

   (it "Subscribers should be provided old and new context, action, effect, and extra"
       (fn []
         (let [fsm (make-fsm)]
           (fsm.subscribe (fn [{: prev-state : next-state : action : effect : extra}]
                            (is.not-eq? prev-state.context.i
                                        next-state.context.i "Subscriber did not get old and new state")
                            (is.eq? action :toggle "Subscriber did not get correct action")
                            (is.eq? effect :opening "Subscriber did not get correct effect")
                            (is.eq? extra :extra "Subscriber did not get correct extra")))
           (fsm.send :toggle :extra))))

   (it "Subscribers should be able to unsubscribe"
       (fn []
         (let [fsm (make-fsm)]
           (let [i (atom.new 0)
                 unsub (fsm.subscribe (fn [] (atom.swap! i (fn [v] (+ v 1)))))]
             (fsm.send :toggle)
             (unsub)
             (fsm.send :toggle)
             (is.eq? (atom.deref i) 1 "The subscriber was called after unsubscribing")))))

   (it "Effect handler should maintain cleanup function"
       (fn []
         (let [fsm (make-fsm)
               effect-state (atom.new :unused)
               effect-handler (statemachine.effect-handler
                               {:opening (fn []
                                           (atom.swap! effect-state
                                                       (fn [_ nv] nv) :opened)
                                           ; Returned cleanup func
                                           (fn []
                                             (atom.swap! effect-state
                                                         (fn [_ nv] nv) :cleaned)))})
               unsub (fsm.subscribe effect-handler)]
           (fsm.send :toggle)
           (is.eq? (atom.deref effect-state) :opened "Effect handler should have been called")
           (fsm.send :toggle)
           (is.eq? (atom.deref effect-state) :cleaned "Cleanup function should have been called")
           )))))
