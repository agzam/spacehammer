(local exports {})

(fn exports.eq?
  [actual expected message]
  (assert (= actual expected) (.. message " instead got " (hs.inspect actual))))

(fn exports.not-eq?
  [first second message]
  (assert (not= first second) (.. message " instead both were " (hs.inspect first))))

(fn exports.ok?
  [actual message]
  (assert (= (not (not actual)) true) (.. message " instead got " (hs.inspect actual))))

exports
