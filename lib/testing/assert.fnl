(local exports {})

(fn exports.eq?
  [actual expected message]
  (assert (= actual expected) (.. message " instead got " (hs.inspect actual))))

(fn exports.not-eq?
  [first second message]
  (assert (not= first second) (.. message " instead both were " (hs.inspect first))))

(fn exports.seq-eq?
  [actual expected message]
  (assert (= (length actual) (length expected)) (.. message " instead got different lengths: " (hs.inspect actual)))
  (assert (= (length actual)
             (accumulate [matches 0
                          i a (ipairs actual)]
               (if (= a (. expected i))
                 (+ matches 1)
                 matches))) (.. message " instead got " (hs.inspect actual))))

(fn exports.ok?
  [actual message]
  (assert (= (not (not actual)) true) (.. message " instead got " (hs.inspect actual))))

exports
