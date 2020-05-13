;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

(local fu hs.fnutils)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Simple Utils
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn call-when
  [f]
  "Execute function if it is not nil."
  (when (and f (= (type f) :function))
    (f)))

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
  "Execute a function across a table and return the first element where that function returns true."
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
  (slice-start-end start (length list) list))

(fn slice
  [start end list]
  (if (and (= (type end) :table)
           (not list))
      (slice-start start end)
      (slice-start-end start end list)))

(fn split
  [separator str]
  "Using specified separator, convert string to an array of strings."
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
  (var result acc)
  (each [k v (seq tbl)]
    (set result (f result v k)))
  result)


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

(fn map
  [f tbl]
  (reduce
    (fn [new-tbl v k]
      (table.insert new-tbl (f v k))
      new-tbl)
    []
    tbl))

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

(fn concat
 [...]
 (reduce
  (fn [cat tbl]
    (each [_ v (ipairs tbl)]
      (table.insert cat v))
    cat)
  []
  [...]))

(fn some
  [f tbl]
  (let [filtered (filter f tbl)]
    (<= 1 (length filtered))))


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

{:call-when call-when
 :compose   compose
 :concat    concat
 :contains? contains?
 :count     count
 :eq?       eq?
 :filter    filter
 :find      find
 :for-each  for-each
 :get       get
 :get-in    get-in
 :has-some? has-some?
 :identity  identity
 :join      join
 :last      last
 :logf      logf
 :map       map
 :merge     merge
 :noop      noop
 :reduce    reduce
 :seq       seq
 :seq?      seq?
 :some      some
 :slice     slice
 :split     split
 :tap       tap}
