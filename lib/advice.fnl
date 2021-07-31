(fn afn
  [name args docstring ...]
  ;; TODO: Instrument the function body with calls to its advice
  (let [docstring (tostring docstring)]
    `(global ,name (fn ,args ,docstring
                     (let [orig# (fn ,args ,...)]
                       ;; Call :before funcs with original args
                       (when-let [bfunc# (. _G (.. ,(tostring name) "__before"))]
                                 (bfunc# (table.unpack ,args)))
                       ;; If there is :override, then don't call the original
                       (let [rv# (if-let [ofunc# (. _G (.. ,(tostring name) "__override"))]
                                   (ofunc# (table.unpack ,args))
                                   ;; If there is ::around, call it instead,
                                   ;; providing the original
                                   (if-let [afunc# (. _G (.. ,(tostring name) "__around"))]
                                     (afunc# orig# (table.unpack ,args))
                                     (orig# (table.unpack ,args))))]
                         ;; Call :after funcs
                         (when-let [afunc# (. _G (.. ,(tostring name) "__after"))]
                                   (afunc# (table.unpack ,args)))
                         rv#))))))

(fn defadvice!
  [name args docstring where funcname ...]
  "defadvice! defines an advising function and adds it to the specified function."
  `(do
     (let [add-advice!# (. (require "lib/utils") "add-advice!")]
     (global ,name (fn ,args ,docstring ,...))
     (add-advice!# ,funcname
                  ,where ,name))))

{: afn
 : defadvice!}
