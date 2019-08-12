(require-macros :lib.macros)
(local {:find find} (require :lib.functional))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Hyper Mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; - Bind a key or a combination of keys to trigger a hyper mode.
;; - Often this is cmd+shift+alt+ctrl
;; - Or a virtual F17 key if using something like Karabiner Elements
;; - The goal is to have a mode no other apps will be listening for
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var hyper (hs.hotkey.modal.new))
(var enabled false)

(fn enter-hyper-mode
  []
  (set enabled true)
  (: hyper :enter))

(fn exit-hyper-mode
  []
  (set enabled false)
  (: hyper :exit))

(fn unbind-key
  [key]
  (when-let [binding (find (fn [{:msg msg}]
                             (= msg key))
                           hyper.keys)]
            (: binding :delete)))

(fn bind
  [key f]
  (: hyper :bind nil key nil f)
  (fn unbind
    []
    (unbind-key key)))

(fn bind-spec
  [{:key key
    :mods mods
    :press press-f
    :release release-f
    :repeat repeat-f}]
  (: hyper :bind nil key press-f release-f repeat-f)
  (fn unbind
    []
    (unbind-key key)))

(fn init
  [config]
  (let [h (or config.hyper {})]
    (hs.hotkey.bind (or h.mods [])
                    h.key
                    enter-hyper-mode
                    exit-hyper-mode)))

(fn enabled?
  []
  (= enabled true))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{:init      init
 :bind      bind
 :bind-spec bind-spec
 :enabled?  enabled?}
