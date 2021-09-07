;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

"
Advising API to register functions
"

(require-macros :lib.macros)
(local fennel (require :fennel))
(local {: contains?
        : compose
        : filter
        : first
        : join
        : last
        : map
        : reduce
        : seq
        : slice
        : split} (require :lib.functional))

(var advice {})
(var advisable [])

(fn register-advisable
  [key f]
  (let [advice-entry (. advice key)]
    (when (and advice-entry
               advice-entry.original
               (not (= advice-entry.original f)))
        (error (.. "Advisable function " key " already exists")))
    (if advice-entry
        (tset advice-entry
              :original f)
        (tset advice key
              {:original f
               :advice []}))
    (. advice key)))

(fn get-or-create-advice-entry
  [key]
  "
  Gets or create an advice-entry without an original. This allows
  advice to be added before the advisable function is defined
  "
  (let [advice-entry (. advice key)]
    (if advice-entry
        advice-entry
        (do
          ;; Don't set original as that is used to determine when an
          ;; advisable function by that key was already defined
          (tset advice key {:advice []})
          (. advice key)))))

(fn advisable-keys
  []
  (slice 0 advisable))

(fn get-module-name
  []
  (->> (. (debug.getinfo 3 "S") :short_src)
       (split "/")
       (slice -1)
       (join "/")
       (split "%.")
       (first)))

(fn advisor
  [type f orig-f]
  (if
   (= type :override)
   (fn [args]
     (f (table.unpack args)))

   (= type :around)
   (fn [args]
     (f orig-f (table.unpack args)))

   (= type :before)
   (fn [args]
     (f (table.unpack args))
     (orig-f (table.unpack args)))

   (= type :before-while)
   (fn [args]
     (and (f (table.unpack args))
          (orig-f (table.unpack args))))

   (= type :before-until)
   (fn [args]
     (or (f (table.unpack args))
         (orig-f (table.unpack args))))

   (= type :after)
   (fn [args]
     (let [ret (orig-f (table.unpack args))]
       (f (table.unpack args))
       ret))

   (= type :after-while)
   (fn [args]
     (and (orig-f (table.unpack args))
          (f (table.unpack args))))

   (= type :after-until)
   (fn [args]
     (or (orig-f (table.unpack args))
         (f (table.unpack args))))

   (= type :filter-args)
   (fn [args]
     (orig-f (table.unpack (f (table.unpack args)))))

   (= type :filter-return)
   (fn [args]
     (f (orig-f (table.unpack args))))))

(fn apply-advice
  [entry args]
  (((compose
     (table.unpack (->> entry.advice
                        (map (fn [{: f
                                   : type}]
                               (fn [next-f]
                                 (advisor type f next-f)))))))
    (fn [...] (entry.original (table.unpack [...]))))
   args))

(fn count
  [tbl]
  (->> tbl
       (reduce (fn [acc _x _key]
                 (+ acc 1))
               0)))

(fn dispatch-advice
  [entry [_tbl & args]]
  (if (> (count entry.advice) 0)
      (apply-advice entry args)
      (entry.original (table.unpack args))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public API
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn make-advisable
  [fn-name f]
  "
  Registers a function name against the global advisable table that
  contains advice registered for a function. Advice can be defined
  before a function is defined making it a really safe way to extend
  behavior without exploding config options.

  It is recommended to use the `defn` or `afn` macros instead.

  Usage:
  (make-advisable :some-func (fn some-func [] \"Some return string\"))

  - Supports passing some-func directly into add-advice
  - Supports passing in some-func.key directly into add-advice
  - Supports passing in a string like :path/to/module/some-func to
    add-advice
  "
  (let [module (get-module-name)
        key (.. module "/" fn-name)
        advice-entry (register-advisable key f)
        ret {:key key
             :advice advice-entry}]
    (setmetatable ret
                  {:__name fn-name
                   :__call (fn [...]
                             (dispatch-advice advice-entry [...]))
                   :__index (fn [tbl key]
                              (. tbl key))})
    (each [k v (pairs (or (. fennel.metadata f) []))]
      (: fennel.metadata :set ret k v))
    ret))

(fn add-advice
  [f advice-type advice-fn]
  "
  Register advice for an advisable function. It is recommended to use
  the `defadvice` macro instead.

  Takes a key string or a callable table with a key property, an
  advising type key string, and an advising function

  Returns nil, as it performs a side-effect
  "
  (let [key (or f.key f)
        advice-entry (get-or-create-advice-entry key)]
    (when advice-entry
      (table.insert advice-entry.advice {:type advice-type :f advice-fn}))))

(fn remove-advice
  [f advice-type advice-fn]
  "
  Remove advice from a function
  "
  (let [key (or f.key f)
        advice-entry (. advice key)]
    (tset advice-entry :advice
          (->> advice-entry.advice
               (filter #(not (and (= $1.type  advice-type)
                                  (= $1.f     advice-fn))))))
    nil))

(fn reset
  []
  "
  Anticipated for internal, testing, and debugging
  Use with Caution
  "
  (set advice {})
  (set advisable []))

(fn print-advisable-keys
  []
  "
  Prints a list of advisable function keys
  "
  (print "\nAdvisable functions:\n")
  (each [i key (ipairs (advisable-keys))]
    (print (.. "  :" key))))

(fn get-advice
  [f-or-key]
  "
  Returns the advice list for a given function or advice entry key
  "
  (let [advice-entry (. advice (or f-or-key.key f-or-key))]
    (if advice-entry
        (map
         (fn [adv]
           {:f (tostring adv.f) :type adv.type})
         (slice 0 advice-entry.advice))
        [])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{: reset
 : make-advisable
 : add-advice
 : remove-advice
 : get-advice
 : print-advisable-keys}
