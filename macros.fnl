(fn advisable-fn
  [name args docstring ...]
  ;; TODO: Instrument the function body with calls to its advice
  (let [docstring (tostring docstring)]
    `(global ,name (fn ,args ,docstring
                     ;; Call :before funcs with original args
                     (if (. _G (.. ,(tostring name) "__before"))
                       (let [bfunc# (. _G (.. ,(tostring name) "__before"))]
                         (bfunc# (table.unpack ,args))))
                     ;; TODO: Call :before-while funcs, shortcircuiting if any returns nil
                     ;; TODO: Unpack its rv into ... (We can't do this, ... is special)
                     ;; If there is :override, then don't run the body
                     (let [rv# (if (. _G (.. ,(tostring name) "__override"))
                                 (let [ofunc# (. _G (.. ,(tostring name) "__override"))]
                                   (ofunc# (table.unpack ,args)))
                                 (do ,...))]
                       ;; Call :after funcs
                       (if (. _G (.. ,(tostring name) "__after"))
                         (let [afunc# (. _G (.. ,(tostring name) "__after"))]
                           (afunc# (table.unpack ,args))))
                       ;; TODO: Call :after-while funcs if rv is not nil
                       rv#
                       )))))

(fn defadvice!
  [name args docstring where funcname ...]
  "defadvice! defines an advising function and adds it to the specified function."
  `(do
     (let [add-advice!# (. (require "lib/utils") "add-advice!")]
     (global ,name (fn ,args ,docstring ,...))
     (add-advice!# ,funcname
                  ,where ,name))))

{: advisable-fn
 : defadvice!}
