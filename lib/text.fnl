(local {:map map
        :merge merge
        :reduce reduce} (require :lib.functional))
;; Menu Column Alignment
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(fn max-length
  [items]
  (reduce
   (fn [max [key _]]  (math.max max (# key)))
   0
   items))


(fn pad-str
  [char max str]
  (let [diff (- max (# str))]
    (.. str (string.rep char diff))))


(fn align-columns
  [items]
  (let [max (max-length items)]
    (map
     (fn [[key action]]
       (.. (pad-str "." (+ max 1) (.. key " ")) "..... " action))
     items)))

{:align-columns align-columns}
