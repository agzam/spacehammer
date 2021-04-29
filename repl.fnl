(local fennel (require :fennel))
(local jeejah (require :jeejah))
(local view (require :fennelview))
(var server nil)

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


(fn start
  []
  (set server (jeejah.start nil {:fennel true
                                 :middleware fennel-middleware
                                 :debug true}))
  (print (hs.inspect server))
  server)

(fn stop
  []
  (jeejah.stop server)
  (set server nil))

{:start start
 :stop stop}
