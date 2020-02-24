;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

(require-macros :lib.macros)
(local {:find find} (require :lib.functional))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Hyper Mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; - Bind a key or a combination of keys to trigger a hyper mode.
;; - Often this is cmd+shift+alt+ctrl
;; - Or a virtual F17 key if using something like Karabiner Elements
;; - The goal is to give you a whole keyboard worth of bindings that don't
;;   conflict with any other apps.
;; - In config.fnl, put :hyper in a global key binding's mods list like [:hyper]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var hyper (hs.hotkey.modal.new))
(var enabled false)

(fn enter-hyper-mode
  []
  "
  Globally enables hyper mode
  Only performs a side effect of marking the mode as enabled and enabling the
  hotkey modal.
  "
  (set enabled true)
  (: hyper :enter))

(fn exit-hyper-mode
  []
  "
  Globally disables hyper mode
  Only performs a side effect of marking the mode as not enabled and exits
  hyper mode
  "
  (set enabled false)
  (: hyper :exit))

(fn unbind-key
  [key]
  "
  Remove a binding from the hyper hotkey modal
  Performs a side effect when a binding matches a target key
  Side effect: Changes hotkey modal
  "
  (when-let [binding (find (fn [{:msg msg}]
                             (= msg key))
                           hyper.keys)]
            (: binding :delete)))

(fn bind
  [key f]
  "
  Bind a key on the hyper hotkey modal
  Takes a key string and a function to call when key is pressed
  Returns a function to remove the binding for this key.
  "
  (: hyper :bind nil key nil f)
  (fn unbind
    []
    (unbind-key key)))

(fn bind-spec
  [{:key key
    :press press-f
    :release release-f
    :repeat repeat-f}]
  "
  Creates a hyper hotkey modal binding based on a binding spec table
  Takes a table:
  - key <string> A hotkey
  - press <function> A function to bind when the key is pressed down
  - release <function> A function to bind when the key is released
  - repeat <function> A function to bind when thek ey is repeated
  "
  (: hyper :bind nil key press-f release-f repeat-f)
  (fn unbind
    []
    (unbind-key key)))

(fn init
  [config]
  "
  Initializes the hyper module
  - Binds the hyper keys defined in config.fnl
  - Uses config.fnl :hyper as the key to trigger hyper mode
    A default like :f17 or :f18 is recommended
  - Binds the config.hyper key to enter hyper mode on press and exit upon
    release.
  "
  (let [h (or config.hyper {})]
    (hs.hotkey.bind (or h.mods [])
                    h.key
                    enter-hyper-mode
                    exit-hyper-mode)))

(fn enabled?
  []
  "
  An API function to check if hyper mode is enabled
  Returns true if hyper mode is enabled
  "
  (= enabled true))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{:init      init
 :bind      bind
 :bind-spec bind-spec
 :enabled?  enabled?}
