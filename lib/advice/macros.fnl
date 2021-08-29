;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

"
Macros to create advisable functions or register advice for advisable functions
"

(fn defn
  [fn-name args docstr body1 ...]
  "
  Define an advisable function, typically as a module-level function.
  Can be advised with the defadvice macro or add-advice function

  @example
  (defn greeting
    [name]
    \"Advisable greeting function\"
    (print \"Hello\" name))
  "
  (assert (= (type docstr) :string) "A docstr required for advisable functions")
  (assert body1 "advisable function expected body")
  (let [fn-name-str (tostring fn-name)]
    `(local ,fn-name
            (let [adv# (require :lib.advice)]
              (adv#.make-advisable ,fn-name-str (fn ,args ,docstr ,body1 ,...))))))

(fn afn
  [fn-name args body1 ...]
  "
  Define an advisable function in as a function expression. These should be used
  with caution to support when an API function is created from another parent
  function call.

  @example
  (let [f (afn local-greeting
            [name]
            \"Advisable greeting but local to this scope\")
            (print \"Hello\" name)]
    (f))
  "
  (assert body1 "advisable function expected body")
  (let [fn-name-str (tostring fn-name)]
    `(let [adv# (require :lib.advice)]
       (adv#.make-advisable ,fn-name-str (fn ,args ,body1 ,...)))))



(fn defadvice
  [fn-name args advice-type f-or-key docstr body1 ...]
  "
  Define advice for an advisable function. Syntax sugar for calling
  (add-advice key-or-advisable-fn (fn [] ...))

  @example
  (defadvice my-advice-fn
    [x y z]
    :override original-fn
    \"Override original-fn\"
    (* x y z))
  "
  (assert (= (type docstr) :string) "A docstr is required for defining advice")
  (assert body1 "advisable function expected body")
  `(local ,fn-name
          (let [adv# (require :lib.advice)
                advice-fn# (setmetatable
                            {}
                            {:__name ,(tostring fn-name)
                             :__call (fn ,fn-name ,args ,docstr ,body1 ,...)})]
            (adv#.add-advice ,f-or-key ,advice-type advice-fn#)
            advice-fn#)))

{: afn
 : defn
 : defadvice}
