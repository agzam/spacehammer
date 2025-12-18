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

(fn every?
  [pred iter]
  (accumulate [result true
               k v (iter)
               &until (not result)]
   (and result (pred k v))))

(fn exports.table-eq? [actual expected message]
  ;; Ensure both are tables
  (if (and (= (type actual) :table)
           (= (type expected) :table))
    ;; NOTE: We have to wrap the iterators in a function returning
    ;; them so all can use them in `each`
    (assert (and
              ;; Ensure all keys in actual are in expected
              (every? (fn [k v] (= v (. expected k))) #(pairs actual))
              ;; Ensure all keys in expected are in actual, to ensure
              ;; expected isn't just a superset
              (every? (fn [k v] (= v (. actual k))) #(pairs expected)))
            (.. message " expected " (hs.inspect expected) " instead got " (hs.inspect actual)))
    (assert false (.. message " expected two tables but got "
                      (type actual) " and " (type expected)))))

(fn exports.ok?
  [actual message]
  (assert (= (not (not actual)) true) (.. message " instead got " (hs.inspect actual))))

exports
