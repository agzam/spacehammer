(local is (require :lib.testing.assert))
(local f (require :lib.functional))


(describe
  "Functional"
  (fn []

    (it "Call when calls function if it exists"
        (fn []
          (is.eq? (f.call-when (fn [] 2)) 2 "Unexpected result")
          (is.eq? (f.call-when nil) nil "Call-when did not return nil")))

    (it "Call when passes args"
        (fn []
          (is.eq? (f.call-when (fn [a] a) 3) 3 "Unexpected result")))

    (it "Compose combines functions together in reverse order"
        (fn []
          (is.eq? ((f.compose #(+ 1 $1) #(- $1 2) #(* 3 $1)) 2) 5 "Unexpected result")))


    (it "Contains? returns true if list table contains a value"
        (fn []
          (is.eq? (f.contains? :b [:a :b :c]) true "contains? did not return true")
          (is.eq? (f.contains? :d [:a :b :c]) false "contains? did not return false")))

    (it "find returns an item from table list that matches predicate"
        (fn []
          (is.eq? (f.find #(= $1 :b) [:a :b :c]) :b "find did not return :b")))

    (it "Concat returns a table with combined elements"
        (fn []
          (is.seq-eq? (f.concat [6 5 4] [3 2 1]) [6 5 4 3 2 1] "concat did not return combined values")
          (is.seq-eq? (f.concat [6 5] [4 3] [2 1]) [6 5 4 3 2 1] "concat did not return combined values")))

    (it "Filter picks items from a list"
        (fn []
          (is.seq-eq? (f.filter #(> $1 3) [1 2 3 4 5 6]) [4 5 6] "filter did not select items greater than 3")))

    (it "Some returns true if predicate function finds match in table"
        (fn []
          (is.eq? (f.some #(> $1 3) [1 2 3 4 5 6]) true "some did not find that table has elements greater than 3")
          (is.eq? (f.some #(> $1 3) [1 2 3]) false "some incorrectly found that table has elements greater than 3")))
    ))
