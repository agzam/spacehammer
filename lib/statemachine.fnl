(local atom (require :lib.atom))
(local {:filter filter
        :logf logf
        :map map
        :merge merge
        :tap tap} (require :lib.functional))

(local log (hs.logger.new "\tstatemachine.fnl\t" "debug"))

"
Transition
Takes an action fn, state, and extra action data
Returns updated state
"
(fn transition
  [action-fn state data]
  (action-fn state data))


"
Remove Nils
Takes a dest table and an update.
For each key in update set to :nil, it is removed from the tbl.
Returns a mutated tbl with :nil keys removed.
"
(fn remove-nils
  [tbl update]
  (let [keys (->> update
               (map (fn [v k] [v k]))
               (filter (fn [[v _]]
                         (= v :nil)))
               (map (fn [[_ k]] k)))]
    (each [_ k (ipairs keys)]
      (tset tbl k nil))
    tbl))

"
Update State
Takes a state atom and an update table to merge
Updates the state-atom by merging the update table into previous state.
Returns the state-atom.
"
(fn update-state
  [state-atom update]
  (when update
    (atom.swap!
     state-atom
     (fn [state]
       (-> {}
           (merge state update)
           (remove-nils update))))))

"
Dispatch Error
Prints an error explaining that we are not able to perform the target
action while in the current state.
"
(fn dispatch-error
  [current-state-key action-name]
  (log.wf "Could not %s from %s state"
          action-name
          current-state-key))

"
Creates Dispatcher
Creates a dispatcher function to update the machine state atom.
If an update cannot be performed an error is printed to console.

Takes a table of states, a state-atom, and a state-key used to store the current
state keyword/string.
Returns a function that can be used as a method of the fsm to transition to
another state.
"
(fn create-dispatcher
  [states state-atom state-key]
  (fn dispatch
    [action data]
    (let [state (atom.deref state-atom)
          key (. state state-key)
          action-fn (-?> states
                         (. key)
                         (. action))]
      (if action-fn
          (do
            (update-state state-atom (transition action-fn state data))
            true)
          (do
            (dispatch-error key action)
            false)))))


"
Create Machine
Creates a finite-state-machine based on the table of given states.
Takes a map-table of states and actions, an initial state table, and a key
to specify which key stores the current state string.
Returns an fsm table that manages state and can dispatch actions.

Example:

(local states
       {:idle   {:activate   idle->active
                 :enter-app  idle->in-app}
        :active {:deactivate active->idle-or-in-app
                 :activate   active->active
                 :enter-app  active->active
                 :leave-app  active->active}
        :in-app {:activate   in-app->active
                 :enter-app  in-app->in-app
                 :leave-app  in-app->idle}})

(local fsm (create-machine states {:state :idle} :state))
(fsm.dispatch :activate {:extra :data})
(print \"current-state: \" (hs.inspect (atom.deref (fsm.state))))
"
(fn create-machine
  [states initial-state state-key]
  (let [machine-state (atom.new initial-state)]
    {:dispatch (create-dispatcher states machine-state state-key)
     :states states
     :state machine-state}))

{:new create-machine}
