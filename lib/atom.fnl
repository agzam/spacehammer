(fn atom
  [initial]
  {:state initial
   :watchers {}})

(fn copy
  [tbl]
  (if (~= (type tbl) :table)
   tbl
   (let [copy-tbl (setmetatable {} (getmetatable tbl))]
     (each [k v (pairs tbl)]
       (tset copy-tbl (copy k) (copy v)))
     copy-tbl)))

(fn deref
  [atom]
  (. atom :state))

(fn notify-watchers
  [atom next-value prev-value]
  (let [watchers (. atom :watchers)]
    (each [_ f (pairs watchers)]
      (f next-value prev-value))))

(fn add-watch
  [atom key f]
  (tset atom :watchers key f))

(fn remove-watch
  [atom key]
  (table.remove (. atom :watchers) key))

(fn swap!
  [atom f ...]
  (let [prev-value (deref atom)
        next-value (f (copy prev-value) (table.unpack [...]))]
    (set atom.state next-value)
    (notify-watchers atom next-value prev-value)
    atom))

{:atom atom
 :new atom
 :deref deref
 :notify-watchers notify-watchers
 :add-watch add-watch
 :remove-watch remove-watch
 :swap! swap!}
