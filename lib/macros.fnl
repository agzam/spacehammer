(fn when-let
  [[var-name value] body1 ...]
  (assert body1 "expected body")
  `(let [@var-name @value]
     (when @var-name
       @body1 @...)))

{:when-let when-let}
