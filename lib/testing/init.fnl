(var suites [])
(var state {:suite nil
            :before []
            :after []
            :ran 0
            :failed 0
            :passed 0})

;; 4-bit colors
;; https://i.stack.imgur.com/9UVnC.png

(local colors {:red   "31"
               :green "92"})

(fn describe
  [suite-name suite-f]
  (table.insert suites {:name suite-name
                        :suite suite-f
                        :before []
                        :after []
                        :tests []}))

(fn it
  [description test-f]
  (if state.suite
      (table.insert state.suite.tests {:desc description
                                       :test test-f})))

(fn before
  [before-f]
  (if state.suite
      (table.insert state.suite.before before-f)
      (table.insert state.before before-f)))

(fn after
  [after-f]
  (if state.suite
      (table.insert state.suite.after after-f)
      (table.insert state.after after-f)))

(fn collect-tests
  []
  (each [i suite-map (ipairs suites)]
    (tset state :suite suite-map)
    (suite-map.suite))
  suites)

(fn color
  [text color]
  (assert (. colors color) (.. "Color " color " could not be found"))
  (.. "\27[" (. colors color) "m" text "\27[0m"))


(fn green
  [text]
  (color text :green))

(fn red
  [text]
  (color text :red))

(fn try-test
  [f]
  (let [(ok err) (xpcall f (fn [err]
                             (do
                               (tset state :failed (+ state.failed 1))
                               (print (.. "    " (red "[ FAIL ]") "\n"))
                               (print (debug.traceback err) "\n"))))]
    (if ok
        (do
          (print  (.. "    " (green "[ OK ]") "\n"))
          (tset state :passed (+ state.passed 1)))
        )))

(fn init
  []
  (set suites [])
  (set state {:suite nil
              :before []
              :after []
              :ran 0
              :failed 0
              :passed 0}))

(fn run-all-tests
  []
  (print "")
  (let [start (os.clock)]
    (each [i before-f (ipairs state.before)]
      (before-f))
    (each [i suite-map (ipairs suites)]
      (print suite-map.name "\n")
      (each [i before-f (ipairs suite-map.before)]
        (before-f))
      (each [_ test-map (ipairs suite-map.tests)]
        (print (.. "  " test-map.desc " ...  \t"))
        (try-test test-map.test)
        (tset state :ran (+ state.ran 1)))
      (each [i after-f (ipairs suite-map.after)]
        (after-f)))
    (each [i after-f (ipairs state.after)]
      (after-f))
    (let [end (os.clock)
          elapsed (- end start)]
      (print (.. "\n  Ran " state.ran " tests " (green state.passed) " passed " (red state.failed) " failed in " elapsed " seconds"))
      (when (> state.failed 0)
        (error "Tests failed")))))

{: init
 : suites
 : after
 : before
 : it
 : describe
 : collect-tests
 : run-all-tests}
