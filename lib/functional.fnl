(local fu hs.fnutils)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Simple Utils
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn call-when
  [f ...]
  "Execute function if it is not nil."
  (when (and f (= (type f) :function))
    (f ...)))

(fn compose
  [...]
  (let [fs [...]
        total (length fs)]
    (fn [v]
      (var res v)
      (for [i 0 (- total 1)]
        (let [f (. fs (- total i))]
          (set res (f res))))
      res)))

(fn contains?
  [x xs]
  "Returns true if key is present in the given collection, otherwise returns false."
  (and xs (fu.contains xs x)))

(fn find
  [f tbl]
  "Executes a function across a table and return the first element where that
  function returns true.
  "
  (fu.find tbl f))

(fn get
  [prop-name tbl]
  (if tbl
      (. prop-name tbl)
      (fn [tbl]
        (. tbl prop-name))))

(fn has-some?
  [list]
  (and list (< 0 (length list))))

(fn identity
  [x] x)

(fn join
  [sep list]
  (table.concat list sep))

(fn first
  [list]
  (. list 1))

(fn last
  [list]
  (. list (length list)))

(fn logf
  [...]
  (let [prefixes [...]]
    (fn [x]
      (print (table.unpack prefixes) (hs.inspect x)))))

(fn noop
  []
  nil)

(fn range
  [start end]
  (let [t []]
    (for [i start end]
      (table.insert t i))
    t))

(fn slice-end-idx
  [end-pos list]
  (if (< end-pos 0)
    (+ (length list) end-pos)
    end-pos))

(fn slice-start-end
  [start end list]
  (let [end+ (if (< end 0)
              (+ (length list) end)
              end)]
    (var sliced [])
    (for [i start end+]
      (table.insert sliced (. list i)))
    sliced))

(fn slice-start
  [start list]
  (slice-start-end (if (< start 0)
                       (+ (length list) start)
                       start) (length list) list))

(fn slice
  [start end list]
  (if (and (= (type end) :table)
           (not list))
      (slice-start start end)
      (slice-start-end start end list)))

(fn split
  [separator str]
  "Converts string to an array of strings using specified separator."
  (fu.split str separator))

(fn tap
  [f x ...]
  (f x (table.unpack [...]))
  x)

(fn count
  [tbl]
  "Returns number of elements in a table"
  (var ct 0)
  (fu.each
   tbl
   (fn []
     (set ct (+ ct 1))))
  ct)

(fn apply [f ...]
  (let [args [...]]
    (f (table.unpack args))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reduce Primitives
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn seq?
  [tbl]
  (~= (. tbl 1) nil))

(fn seq
  [tbl]
  (if (seq? tbl)
    (ipairs tbl)
    (pairs tbl)))

(fn reduce
  [f acc tbl]
  (accumulate [acc acc
               k v (seq tbl)]
    (f acc v k)))

(fn concat [...]
  (reduce (fn [cat tbl]
            (each [_ v (ipairs tbl)]
              (table.insert cat v))
            cat) [] [...]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reducers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn for-each
  [f tbl]
  (fu.each tbl f))

(fn get-in
  [paths tbl]
  (reduce
   (fn [tbl path]
     (-?> tbl (. path)))
   tbl
   paths))

(fn zip [...]
  "Groups corresponding elements from multiple lists into a new list, truncating at the length of the smallest list."
  (let [tbls [...]
        result []]
    (if (= 1 (length tbls))
        (table.insert result (. tbls 1))
        (for [idx 1 (length (. tbls 1))]
          (let [inner []]
            (each [_ tbl (ipairs tbls) &until (not (. tbl idx))]
              (table.insert inner (. tbl idx)))
            (table.insert result inner))))
    result))

(fn map [f ...]
  (let [args [...]
        tbls (zip (table.unpack args))]
    (if (= 1 (count args))
        (icollect [_ v (pairs (first args))]
          (apply f v))
        (accumulate [acc []
                     _ t (ipairs tbls)]
          (concat acc [(apply f t)])))))

(fn map-kv [f coll]
  "Maps through an associative table, passing each k/v pair to f"
  (icollect [k v (pairs coll)]
    (f k v)))

(fn merge
  [...]
  (let [tbls [...]]
    (reduce
     (fn merger [merged tbl]
       (each [k v (pairs tbl)]
         (tset merged k v))
       merged)
     {}
     tbls)))

(fn filter
 [f tbl]
 (reduce
  (fn [xs v k]
   (when (f v k)
    (table.insert xs v))
   xs)
  []
  tbl))

(fn some
  [f tbl]
  (let [filtered (filter f tbl)]
    (<= 1 (length filtered))))

(fn conj
  [tbl e]
  "Return a new list with the element e added at the end"
  (concat tbl [e]))

(fn butlast
  [tbl]
  "Return a new list with all but the last item"
  (slice 1 -1 tbl))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Others
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn eq?
  [l1 l2]
  (if (and (= (type l1) (type l2) "table")
           (= (length l1) (length l2)))
      (fu.every l1
                (fn [v] (contains? v l2)))
      (= (type l1) (type l2))
      (= l1 l2)
      false))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{: butlast
 : call-when
 : compose
 : concat
 : conj
 : contains?
 : count
 : eq?
 : filter
 : find
 : first
 : for-each
 : get
 : get-in
 : has-some?
 : identity
 : join
 : last
 : logf
 : map
 : map-kv
 : merge
 : noop
 : reduce
 : seq
 : seq?
 : some
 : slice
 : split
 : tap}
