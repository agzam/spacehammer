(import-macros {: defn
                : afn
                : defadvice} :lib.advice.macros)
(local {: reset
        : make-advisable
        : add-advice
        : remove-advice
        : get-advice
        : print-advisable-keys} (require :lib.advice))

(local fennel (require :fennel))
(local is (require :lib.testing.assert))
(local {: join
        : map} (require :lib.functional))

(describe
 "Advice"
 (fn []
   (before reset)


   (it "Should call unadvised functions as-is"
       (fn []
         (let [test-func (make-advisable
                          :test-func-1
                          (fn test-func-1 [arg]
                            "Advisable test function"
                            (.. "Hello " arg)))]

           (is.eq? (test-func "cat") "Hello cat" "Unadvised test-func did not return \"Hello cat\""))))

   (it "Should call override functions instead"
       (fn []
         (let [test-func (make-advisable
                          :test-func-2
                          (fn [...]
                            "Advisable test function"
                            "Plain pizza"))]

           (add-advice test-func :override (fn [...] (.. "Overrided " (join " " [...]))))
           (is.eq? (test-func "anchovie" "pizza") "Overrided anchovie pizza" "Override test-func did not return \"Overrided anchovie pizza\""))))

   (it "Should support advice added by string name"
       (fn []
         (let [test-func (make-advisable
                          :test-func-2b
                          (fn [...]
                            "Advisable test function"
                            "Plain pizza"))]

           (add-advice :test/advice-test/test-func-2b :override (fn [...] (.. "Overrided " (join " " [...]))))
           (is.eq? (test-func "anchovie" "pizza") "Overrided anchovie pizza" "Override test-func did not return \"Overrided anchovie pizza\""))))

   (it "Should call original when remove-advice is called"
       (fn []
         (let [test-func (make-advisable
                          :test-func-2c
                          (fn [x y z]
                            "Advisable test function"
                            "default"))
               advice-fn (fn [x y z]
                           "over-it")]

           (add-advice    test-func :override advice-fn)
           (remove-advice test-func :override advice-fn)

           (is.eq? (test-func) "default" "Original function was not called"))))

   (it "Should support advice added before advisable function is created"
       (fn []
         (add-advice :test/advice-test/test-func-2d :override
                     (fn [x y z]
                       "over-it"))
         (let [test-func (make-advisable
                          :test-func-2d
                          (fn [...]
                            "Advisable test function"
                            "default"))]

           (is.eq? (test-func) "over-it" "test-func was not advised"))))


   (it "Should call around functions with orig"
       (fn []
         (let [test-func (make-advisable
                          :test-func-3
                          (fn [...]
                            "Advisable test function"
                            ["old" (table.unpack [...])]))]

           (add-advice test-func :around (fn [orig ...] (join " " ["around" (table.unpack (orig (table.unpack [...])))])))
           (is.eq? (test-func "one" "two") "around old one two" "Around test-func did not return \"around one two old\""))))

   (it "Should call before functions"
       (fn []
         (let [state {:calls 0
                      :args ""}
               test-func (make-advisable
                          :test-func-4
                          (fn [...]
                            "Advisable test function"
                            (let [args [...]]
                              (tset state :args (.. state.args " " (join " " (map #(+ $1 2) [...])))))
                            (tset state :calls (+ state.calls 1))))]

           (add-advice test-func :before (fn [...]
                                           (let [args [...]]
                                             (tset state :args (join " " [...])))
                                           (tset state :calls (+ state.calls 1))))
           (test-func 1 2)
           (is.eq? state.calls 2 "Before test-func did not call both the original and before fn")
           (is.eq? state.args "1 2 3 4" "Before test-func did not call both the original and before with the same args"))))

   (it "Should call orig if before-while returns truthy"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-5
                          (fn [...]
                            "Advisable test function"
                            (.. "original " (join " " [...]))))]

           (add-advice test-func
                       :before-while
                       (fn [...]
                         (tset state :called true)
                         true))
           (is.eq? (test-func 1 2) "original 1 2" "Before-while test-func did not call original function")
           (is.eq? state.called true "Before-while test-func advice function was not called"))))

   (it "Should not call orig if before-while returns false"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-5b
                          (fn [...]
                            "Advisable test function"
                            (.. "original " (join " " [...]))))]

           (add-advice test-func
                       :before-while
                       (fn [...]
                         (tset state :called true)
                         false))
           (is.eq? (test-func 1 2) false "Before-while test-func did call original function")
           (is.eq? state.called true "Before-while test-func advice function was not called"))))


   (it "Should call orig if before-until returns falsey value"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-6
                          (fn [...]
                            "Advisable test function"
                            (.. "original " (join " " [...]))))]

           (add-advice test-func
                       :before-until
                       (fn [...]
                         (tset state :called true)
                         false))
           (is.eq? (test-func 1 2) "original 1 2" "Before-until test-func did not call original function")
           (is.eq? state.called true "Before-until test-func advice function was not called"))))


   (it "Should not call orig if before-until returns truthy value"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-6b
                          (fn [...]
                            "Advisable test function"
                            (.. "original " (join " " [...]))))]

           (add-advice test-func
                       :before-until
                       (fn [...]
                         (tset state :called true)
                         true))
           (is.eq? (test-func 1 2) true "Before-until test-func did call original function")
           (is.eq? state.called true "Before-until test-func advice function was not called"))))


   (it "Should call after functions"
       (fn []
         (let [state {:calls 0
                      :args ""}
               test-func (make-advisable
                          :test-func-7
                          (fn [...]
                            "Advisable test function"
                            (let [args [...]]
                              (tset state :args (join " " [...])))
                            (tset state :calls (+ state.calls 1))
                            true))]

           (add-advice test-func :after (fn [...]
                                           (let [args [...]]
                                             (tset state :args (.. state.args " " (join " " (map #(+ $1 2) [...])))))
                                           (tset state :calls (+ state.calls 1))))
           (test-func 1 2)
           (is.eq? state.calls 2 "After test-func did not call both the original and after fn")
           (is.eq? state.args "1 2 3 4" "After test-func did not call both the original and after with the same args"))))


   (it "Should call after-while if orig returns truthy"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-8
                          (fn [...]
                            "Advisable test function"
                            (.. "original " (join " " [...]))))]

           (add-advice test-func
                       :after-while
                       (fn [...]
                         (tset state :called true)
                         true))
           (is.eq? (test-func 1 2) true "After-while test-func did not call original function")
           (is.eq? state.called true "After-while test-func advice function was not called"))))

   (it "Should not call after-while if orig returns falsey"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-8b
                          (fn [...]
                            "Advisable test function"
                            false))]

           (add-advice test-func
                       :after-while
                       (fn [...]
                         (tset state :called true)
                         true))
           (is.eq? (test-func 1 2) false "After-while test-func did not call original function")
           (is.eq? state.called false "After-while test-func advice function was called"))))



   (it "Should call after-until if orig returns falsey value"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-9
                          (fn [...]
                            "Advisable test function"
                            false))]

           (add-advice test-func
                       :after-until
                       (fn [...]
                         (tset state :called true)
                         false))
           (is.eq? (test-func 1 2) false "After-until test-func did not call original function")
           (is.eq? state.called true "After-until test-func advice function was not called"))))

   (it "Should not call after-until if orig returns truthy value"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-9b
                          (fn [...]
                            "Advisable test function"
                            (.. "original " (join " " [...]))))]

           (add-advice test-func
                       :after-until
                       (fn [...]
                         (tset state :called true)
                         false))
           (is.eq? (test-func 1 2) "original 1 2" "After-until test-func did call advise function")
           (is.eq? state.called false "After-until test-func advice function was called"))))

   (it "Should filter args sent to orig function"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-10
                          (fn [...]
                            "Advisable test function"
                            (.. "original " (join " " [...]))))]

           (add-advice test-func
                       :filter-args
                       (fn [arg-1 arg-2]
                         (tset state :called true)
                         [ arg-2 ]))
           (is.eq? (test-func 1 2) "original 2" "Filter-args test-func did call orig function with filtered-args")
           (is.eq? state.called true "Filter-args test-func advice function was not called"))))

   (it "Should filter the return value from orig function"
       (fn []
         (let [state {:called false}
               test-func (make-advisable
                          :test-func-11
                          (fn [...]
                            "Advisable test function"
                            [ "original" (table.unpack [...])]))]

           (add-advice test-func
                       :filter-return
                       (fn [[arg-1 arg-2 arg-3]]
                         (tset state :called true)
                         (.. "filtered " arg-2 " " arg-3)))
           (is.eq? (test-func 1 2) "filtered 1 2" "Filter-return test-func did call advise with orig return")
           (is.eq? state.called true "Filter-return test-func advice function was not called"))))


   (it "Should support the defn macro for defining a function within a scope"
       (fn []
         (defn defn-func-1
               [x y z]
               "docstr"
               (print "Hi"))

         (add-advice defn-func-1 :override (fn [x y z] "over-it"))

         (is.eq? (type defn-func-1) "table" "defn call did not result in a callable table")
         (is.eq? (defn-func-1) "over-it" "defn function was not advised with override")))

   (it "Should support the afn macro for defining inline functions"
       (fn []
         (let [priv-func (afn priv-func [x y z] "default")]
           (add-advice priv-func :override (fn [x y z] "over-it"))

           (is.eq? (type priv-func) "table" "afn did not result in a callable table")
           (is.eq? (priv-func) "over-it" "afn function was not advised with override"))))

   (it "Should support advice added with defadvice"
       (fn []
         (defn defn-func-2
               [x y z]
               "docstr"
               (print "hi"))

         (defadvice defn-func-2-advice [x y z]
                    :override defn-func-2
                    "Override defn-func-2 with this sweet, sweet syntax sugar"
                    "This feature is done!")

         (is.eq? (defn-func-2) "This feature is done!" "defadvice did not advise defn-func-2")))

   (it "Should support advice added with defadvice"
       (fn []
         (defn defn-func-3
               [x y z]
               "docstr"
               "default")

         (is.eq? (defn-func-3) "default" "original-fn did not return default")

         (defadvice defn-func-3-advice [x y z]
                    :override defn-func-3
                    "Override defn-func-3 with this sweet, sweet syntax sugar"
                    "over-it")

         (is.eq? (defn-func-3) "over-it" "defadvice did not advise defn-func-3")

         (remove-advice defn-func-3 :override defn-func-3-advice)

         (is.eq? (defn-func-3) "default" "advice was not removed from original-fn")))

   (it "Should support get-advice returning the advice list for an advised func"
       (fn []
         (defn defn-func-4
               [x y z]
               "docstr"
               "default")

         (defadvice defn-func-4-advice [x y z]
                    :override defn-func-4
                    "Override defn-func-4"
                    "over-it")

         (is.eq? (defn-func-4) "over-it" "defn-func-4 was not advised")
         (is.eq? (length (get-advice defn-func-4)) 1 "advice list should be 1")))


   ))
