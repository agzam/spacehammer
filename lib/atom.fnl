;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

"
Atoms are the functional-programming answer to a variable except better
because you can subscribe to changes.

Mechanically, an atom is a table with a current state property and a
list of watchers.

API is provided to calculate the next value of an atom's state based on
previous value or replacing it.

API is also provided to add watchers which takes a function to receive the
current and next value.

API is also provided to get the value of an atom. This is called dereferencing.

Example:
(local x (atom 5))
(print (hs.inspect x))
;; => {
;; :state 5
;; :watchers {}}
(print (deref x))
;; => 5
;; (swap! x #(+ $1 1))
;; (print (deref x))
;; => 6
;; (add-watch x :my-watcher #(print \"new:\" $1 \" old: \" $2))
;; (reset! x 7)
;; => new: 7 old: 6
;; (print (deref x))
;; => 7
;; (remove-watch x :my-watcher)
"
(fn atom
  [initial]
  "
  Create an atom instance
  Takes an initial value
  Returns atom table instance

  Example:
  (local x (atom 5))
  "
  {:state initial
   :watchers {}})

(fn copy
  [tbl copies]
  "
  Copies a table into a new table
  Allows us to treat tables as immutable. Tracks visited so recursive
  references should be no problem here.
  Returns new table copy
  "
  (let [copies (or copies {})]
    (if (~= (type tbl) :table) tbl
        ;; is a table, but already visited
        (. copies tbl)         (. copies tbl)
        ;; else - Is a table, not yet visited
        (let [copy-tbl {}]
          (tset copies tbl copy-tbl)
          (each [k v (pairs tbl)]
            (tset copy-tbl (copy k copies) (copy v copies)))
          (setmetatable copy-tbl (copy (getmetatable tbl) copies))
          copy-tbl))))

(fn deref
  [atom]
  "
  Dereferences the atom instance to return the current value
  Takes an atom instance
  Returns the current state value of that atom.

  Example:
  (local x (atom 5))
  (print (deref x)) ;; => 5

  "
  (. atom :state))

(fn notify-watchers
  [atom next-value prev-value]
  "
  When updating an atom, call each watcher with the next and previous value.
  Takes an atom instance, the next state value and the previous state value
  Performs side-effects to call watchers
  Returns nil.
  "
  (let [watchers (. atom :watchers)]
    (each [_ f (pairs watchers)]
      (f next-value prev-value))))

(fn add-watch
  [atom key f]
  "
  Adds a watcher function by a given key to an atom instance. Allows us to
  subscribe to an atom for changes.
  Takes an atom instance, a key string, and a function that takes a next and
  previous value.
  Performs a side-effect to add a watcher for the given key. Replace previous
  watcher on given key.
  Returns nil

  Example:
  (local x (atom 5))
  (add-watch x :custom-watcher #(print $1 \" \" $2))
  (swap! x - 1)
  ;; => 4 5
  "
  (tset atom :watchers key f))

(fn remove-watch
  [atom key]
  "
  Removes a watcher function by a given key
  Takes an atom instance and key to target a specific watcher.
  Performs a side-effect of changing an atom
  Returns nil

  Example:
  (local x (atom 5))
  (add-watch x :custom-watcher #(print $1 \" \" $2))
  (swap! x - 1)
  ;; => 4 5
  (remove-watxh x :custom-watcher)
  (swap! x - 1)
  ;; => x (nothing will be printed)
  (deref x)
  ;; => 4
  "
  (table.remove (. atom :watchers) key))

(fn swap!
  [atom f ...]
  "
  API to update an atom's state by performing a calculation against its current
  state value.
  Takes an atom instance and a function that takes the current value of the atom
  plus additional args and returns the new value.
  Performs a side-effect to update atom's state
  Returns the atom instance

  Example:
  (def x (atom 1))
  (swap! x + 1)
  (deref x)
  ;; => 2
  "
  (let [prev-value (deref atom)
        next-value (f (copy prev-value) (table.unpack [...]))]
    (set atom.state next-value)
    (notify-watchers atom next-value prev-value)
    atom))

(fn reset!
  [atom v]
  "
  API to replace an atom's state value with a new value.
  Takes an atom instance and the new value
  Returns the updated atom instance

  Example:
  (local x (atom 1))
  (reset! x 3)
  ;; => x
  (deref x)
  ;; => 3
  "
  (swap! atom (fn [] v)))

{:atom            atom
 :new             atom
 :deref           deref
 :notify-watchers notify-watchers
 :add-watch       add-watch
 :remove-watch    remove-watch
 :reset!          reset!
 :swap!           swap!}
