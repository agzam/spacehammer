(local is (require :lib.testing.assert))
(local f (require :lib.functional))


(describe
 "Functional"
 (fn []

   (it "Call when calls function if it exists"
       (fn []
         (is.eq? (f.call-when (fn [] 2)) 2 "Unexpected result")
         (is.eq? (f.call-when nil) nil "Call-when did not return nil")))


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

   ))
