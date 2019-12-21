(fn when-let
  [[var-name value] body1 ...]
  (assert body1 "expected body")
  `(let [,var-name ,value]
     (when ,var-name
       ,body1 ,...)))

(fn if-let
  [[var-name value] body1 ...]
  (assert body1 "expected body")
  `(let [,var-name ,value]
     (if ,var-name
       ,body1
       ,...)))

{:when-let when-let
 :if-let if-let}
