(print "Package path in test-runner") ; DELETEME
(print package.path) ; DELETEME
; (local fennel (require :fennel))
(local fennel (require :spacehammer.vendor.fennel))
(print "Fennel path in test-runner") ; DELETEME
(print fennel.path) ; DELETEME
; (local fennel (require :spacehammer.vendor.fennel))
(print "Imported fennel")
(require :spacehammer.lib.globals)
(local {: map
        : slice
        : pprint}  (require :spacehammer.lib.functional))

; (local homedir (os.getenv "HOME"))
; (local customdir (.. homedir "/.spacehammer"))
; (tset fennel :path (.. customdir "/?.fnl;" fennel.path))
; (tset fennel :path (.. customdir "/?/init.fnl;" fennel.path))

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
  (print "in load-tests") ; DELETEME
  (print "xx" (hs.inspect args)) ; DELETEME
  (init)
  (let [[dir & test-files] (slice 2 args)]
    (each [i test-file (ipairs test-files)]
      (let [test-file-path (hs.fs.pathToAbsolute (.. dir "/" test-file))]
        (print "Running tests for" test-file-path)
        (fennel.dofile test-file-path))))

  (collect-tests)
  (run-all-tests))

{: load-tests}
