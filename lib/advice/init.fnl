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

(fn add-advice
  [f advice-type advice-fn]
  (let [key (or f.key f)
        advice-entry (. advice key)]
    (when advice-entry
      (table.insert advice-entry.advice {:type advice-type :f advice-fn}))))

(fn remove-advice
  [advice-type f]
  (let [key f.key
        advice-entry (. advice key)]
    (tset advice-entry :advice
          (->> advice-entry.advice
               (filter #(not (and (= $1.type  advice-type)
                                  (= $1.f     f))))))
    nil))

(fn register-advisable
  [key f]
  ;; @TODO Replace with if-let or similar macro but doesn't work in an isolated fennel file
  (when (contains? key advisable)
    (error (.. "Advisable function" key "already exists")))
  (table.insert advisable key)
  (let [advice-entry (. advice key)]
    (if advice-entry
        advice-entry
        (tset advice key
              {:original f
               :advice []}))))

(fn advisable-keys
  []
  (slice 0 advisable))

(fn print-advisable-keys
  []
  (print "\nAdvisable functions:\n")
  (each [i key (ipairs (advisable-keys))]
    (print (.. "  :" key))))

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
     (orig-f (table.unpack args))
     (f (table.unpack args)))


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
  [key [_tbl & args]]
  (let [entry (. advice key)]
    (if (> (count entry.advice) 0)
        (do
          (apply-advice entry args))
        (do
          (entry.original (table.unpack args))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public API
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn make-advisable
  [fn-name f]
  "
  Registers a function name against the global advisable table that contains
  advice registered for a function. Advice can be defined before a function is
  defined making it a really safe way to extend behavior without exploding
  config options.

  Usage:
  (make-advisable :some-func (fn some-func [] \"Some return string\"))

  - Supports passing some-func directly into add-advice
  - Supports passing in some-func.key directly into add-advice
  - Supports passing in a string like :path/to/module/some-func to add-advice
  "
  (let [module (get-module-name)
        key (.. module "/" fn-name)
        advice-reg (register-advisable key f)
        ret {:key key}]
    (setmetatable ret
                  {:__call (fn [...]
                             (dispatch-advice key [...]))
                   :__index (fn [tbl key]
                              (. tbl key))})
    (each [k v (pairs (or (. fennel.metadata f) []))]
      (: fennel.metadata :set ret k v))
    ret))

(fn reset
  []
  (set advice {})
  (set advisable []))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{: reset
 : make-advisable
 : add-advice
 : remove-advice
 : advisable-keys
 : print-advisable-keys}
