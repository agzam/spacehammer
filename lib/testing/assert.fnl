(local exports {})

(fn exports.eq?
  [actual expected message]
  (assert (= actual expected) (.. message " instead got " (hs.inspect actual))))

(fn exports.ok?
  [actual message]
  (assert (= (not (not actual)) true) (.. message " instead got " (hs.inspect actual))))

exports
