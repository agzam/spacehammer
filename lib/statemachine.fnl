"
Provides the mechanism to generate a finite state machine.

A finite state machine defines states and some way to transition between states.

The 'new' function takes a template, which is a table with the following schema:
{
 :state {:current-state :state1
         :context {}}
 :states {:state1 {}
          :state2 {}
          :state3 {:leave transition-fn-leave
                   :exit transition-fn-exit}}}

* The CONTEXT is any table that can be updated by TRANSITION FUNCTIONS. This
  allows the client to track their own state.
* The STATES table is a map from ACTIONS to TRANSITION FUNCTIONS.
* These functions must return a TRANSITION OBJECT containing the new
  :state and the :effect.
* The :state contains a (potentially changed) :current-state and a new :context,
  which is updated in the state machine.
* Functions can subscribe to all transitions, and are provided a TRANSITION
  RECORD, which contains:
  * :prev-state
  * :next-state
  * :action
  * :effect that was kicked off from the transition function
* The subscribe method returns a function that can be called to unsubscribe.

Additionally, we provide a helper function `effect-handler`, which is a
higher-order function that returns a function suitable to be provided to
subscribe. It takes a map of EFFECTs to handler functions. These handler
functions should return their own cleanup. The effect-handler will automatically
call this cleanup function after the next transition. For example, if you want
to bind keys when a certain effect is kicked off, write a function that binds
the keys and returns an unbind function. The unbind function will be called on
the next transition.
"


(require-macros :lib.macros)
(local atom (require :lib.atom))
(local {: butlast
        : call-when
        : concat
        : conj
        : last
        : merge
        : slice} (require :lib.functional))


(fn update-state
  [fsm state]
  (atom.swap! fsm.state (fn [_ state] state) state))

(fn get-transition-function
  [fsm current-state action]
  (. fsm.states current-state action))

(fn get-state
  [fsm]
  (atom.deref fsm.state))

(fn send
  [fsm action extra]
  "
  Based on the action and the fsm's current-state, set the new state and call
  all subscribers with the previous state, new state, action, and extra.
  "
  (let [state (get-state fsm)
        {: current-state : context} state]
    (if-let [tx-fn (get-transition-function fsm current-state action)]
            (let [
                  transition (tx-fn state action extra)
                  new-state (if transition transition.state state)
                  effect (if transition transition.effect nil)]

              (update-state fsm new-state)
              ; Call all subscribers
              (each [_ sub (pairs (atom.deref fsm.subscribers))]
                (sub {:prev-state state :next-state new-state : action : effect : extra}))
              true)
            (do
              (if fsm.log
                  (fsm.log.df "Action :%s does not have a transition function in state :%s"
                              action current-state))
              false))))

(fn subscribe
  [fsm sub]
  "
  Adds a subscriber to the provided fsm. Returns a function to unsubscribe
  Naive: Because each entry is keyed by the function address it doesn't allow
  the same function to subscribe more than once.
  "
  (let [sub-key (tostring sub)]
    (atom.swap! fsm.subscribers (fn [subs sub]
                                  (merge {sub-key sub} subs)) sub)
    ; Return the unsub func
    (fn []
      (atom.swap! fsm.subscribers (fn [subs key] (tset subs key nil) subs) sub-key))))

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
      ;; Whenever a transition occurs, call the cleanup function, if set
      (call-when (atom.deref cleanup-ref))
      ;; Get a new cleanup function or nil and update cleanup-ref atom
      (atom.reset! cleanup-ref
                   (call-when (. effect-map effect) next-state extra)))))

(fn create-machine
  [template]
  (let [fsm  {:state (atom.new {:current-state template.state.current-state :context template.state.context})
              :states template.states
              :subscribers (atom.new {})
              :log (if template.log (hs.logger.new template.log "info"))}]
    ; Add methods
    (tset fsm :get-state (partial get-state fsm))
    (tset fsm :send (partial send fsm))
    (tset fsm :subscribe (partial subscribe fsm))
    fsm))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{: effect-handler
 : send
 : subscribe
 :new create-machine}
