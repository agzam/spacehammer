(local coroutine (require :coroutine))
(local fennel (require :fennel))
(local jeejah (require :jeejah))
(local view (require :fennelview))

(fn fennel-middleware
  [f msg]
  (match msg.op
    "load-file" (let [f (assert (io.open msg.filename "rb"))]
                  (tset msg
                        :op "eval"
                        :code (-> f
                                  (: :read "*all")
                                  (: :gsub "^#![^\n]*\n" "")))
                  (: f :close))
    (f msg)))

(local repl-coro-freq 0.05)

(fn run
  [server]
  (let [repl-coro server
        repl-spin (fn [] (coroutine.resume repl-coro))
        repl-chk (fn [] (not= (coroutine.status repl-coro) "dead"))]
    (hs.timer.doWhile repl-chk repl-spin repl-coro-freq)))

(fn start-opts
  [opts]
  (let [server (jeejah.start nil opts)]
    server))

(fn start
  []
  (start-opts {:fennel true
               :middleware fennel-middleware
               :debug true}))

(fn stop
  [server]
  (jeejah.stop server))

{:run run
 :start start
 :start-opts start-opts
 :stop stop}
