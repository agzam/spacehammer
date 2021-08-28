(local is (require :lib.testing.assert))
(local statemachine (require :lib.statemachine))
(local atom (require :lib.atom))

(fn make-fsm
  []
  (statemachine.new
   ;; States that the machine can be in mapped to their actions and transitions
   {:closed {:open (fn closed->opened
                     [machine event]
                     {:state :opened
                      :context {:i (+ machine.context.i 1)
                                :event event}})}
    :opened {:close (fn opened->closed
                      [machine event]
                      {:state :closed
                       :context {:i (+ machine.context.i 1)
                                 :event event}})}}

   ;; Initial machine state
   {:state   :closed
    :context {:i     0
              :event nil}}

   ;; Key that refers to current machine state
   :state))

(describe
 "State Machine"
 (fn []

   (it "Should create a new fsm in the closed state"
       (fn []
         (let [fsm (make-fsm)]
           (is.eq? (. (atom.deref fsm.state) :state) :closed "Initial state was not closed")
           (is.eq? (type fsm.dispatch) :function "Dispatch was not a function"))))

   (it "Should transition to opened on open event"
       (fn []
         (let [fsm (make-fsm)]
           (is.eq? (fsm.dispatch :open :opening) true "Dispatch did not return true for handled event")
           (is.eq? (. (atom.deref fsm.state) :state) :opened "State did not transition to opened")
           (is.eq? (. (atom.deref fsm.state) :context :event) :opening "Context data was not updated with event data"))))

   (it "Should transition back to opened on close event"
       (fn []
         (let [fsm (make-fsm)]
           (fsm.dispatch :open :opening)
           (fsm.dispatch :close :closing)
           (is.eq? (. (atom.deref fsm.state) :state) :closed "State did not transition back to closed")
           (is.eq? (. (atom.deref fsm.state) :context :i) 2  "context.i should be 2 from 2 transitions")
           (is.eq? (. (atom.deref fsm.state) :context :event) :closing "Context data was not updated with event data"))))

   (it "Should not explode when dispatching an unhandled event"
       (fn []
         (let [fsm (make-fsm)]
           (is.eq? (fsm.dispatch :fail nil) false "The FSM exploded from dispatching a :fail event"))))


   ))
