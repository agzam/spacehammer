;; Copyright (c) 2017-2021 Ag Ibragimov & Contributors
;;
;;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

(local coroutine (require :coroutine))
(local fennel (require :fennel))
(local jeejah (require :jeejah))
(local view (require :fennelview))
(local {:merge merge} (require :lib.functional))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; nREPL support
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; This module adds support to start an nREPL server. This allows a client to
;; connect to the running server and interact with it while it is running, which
;; can help avoid repeatedly reloading the config.
;;
;; Example usage:
;;
;; - To your ~/.spacehammer/config.fnl add:
;;   (local repl (require :repl))
;;   (repl.run (repl.start))
;;
;; repl.start takes an optional 'opts' table with the following fields:
;; - port: Define the port to listen on (default 7888)
;; - fennel: Expect fennel code (as opposed to lua) (default true)
;; - serialize: Provide a function that converts objects to strings
;;   (default hs.inspect)

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
    _ (f msg)))

(local default-opts
       {:port nil
        :fennel true
        :middleware fennel-middleware
        :serialize hs.inspect})

(local repl-coro-freq 0.05)

(fn run
  [server]
  (let [repl-coro server
        repl-spin (fn [] (coroutine.resume repl-coro))
        repl-chk (fn [] (not= (coroutine.status repl-coro) "dead"))]
    (hs.timer.doWhile repl-chk repl-spin repl-coro-freq)))

(fn start
  [custom-opts]
  (let [opts (merge {} default-opts custom-opts)
        server (jeejah.start (. opts :port) opts)]
    server))

(fn stop
  [server]
  (jeejah.stop server))

{:run run
 :start start
 :stop stop}
