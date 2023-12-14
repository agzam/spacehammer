(local fennel (require :spacehammer.vendor.fennel))
(require :spacehammer.lib.globals)
(local {: map
        : slice
        : pprint}  (require :spacehammer.lib.functional))

;; Setup some globals for test files and debugging


(global {: after
         : before
         : describe
         : it} (require :spacehammer.lib.testing))

;; Pull in some locals from the testing library as well

(local {: init
        : collect-tests
        : run-all-tests} (require :spacehammer.lib.testing))

(fn load-tests
  [args]

  "
  Takes a list of args starting with a directory
  Runs each test file using fennel.dofile
  "
  (init)
  (let [[dir & test-files] (slice 2 args)]
    (each [i test-file (ipairs test-files)]
      (let [test-file-path (hs.fs.pathToAbsolute (.. dir "/" test-file))]
        (print "Running tests for" test-file-path)
        (fennel.dofile test-file-path))))



  (collect-tests)
  (run-all-tests))


{: load-tests}
