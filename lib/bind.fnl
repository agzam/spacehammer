;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;;
;;; Contributors:
;;   Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

(local hyper (require :lib.hyper))
(local {:contains? contains?
        :map       map
        :split     split}
       (require :lib.functional))

(local log (hs.logger.new "bind.fnl" "debug"))

(fn do-action
  [action args]
  "
  Resolves an action string to a function in a module then runs that function.
  Takes an action string like \"lib.bind:do-action\"
  Performs side-effects.
  Returns the return value of the target function or nil if function could
  not be resolved.
  "
  (let [[file fn-name] (split ":" action)
        module (require file)
        f (. module fn-name)]
    (if f
        (f (table.unpack (or args [])))
        (do
          (log.wf "Could not invoke action %s"
                  action)))))


(fn create-action-fn
  [action]
  "
  Takes an action string
  Returns function to resolve and execute action.

  Example:
  (hs.timer.doAfter 1 (create-action-fn \"messages:greeting\"))
  ; Waits 1 second
  ; Looks for a function called greeting in messages.fnl
  "
  (fn [...]
    (do-action action [...])))


(fn action->fn
  [action]
  "
  Normalize an action like say from config.fnl into a function
  Takes an action either a string like \"lib.bind:action->fn\" or an actual
  function instance.
  Returns a function to perform that action or logs an error and returns
  an always true function if a function could not be found.
  "
  (match (type action)
    :function action
    :string (create-action-fn action)
    _         (do
                (log.wf "Could not create action handler for %s"
                        (hs.inspect action))
                (fn [] true))))


(fn bind-keys
  [items]
  "
  Binds keys defined in config.fnl to action functions.
  Takes a list of bindings from a config.fnl menu
  Performs side-effect of binding hotkeys to action functions.
  Returns a function to remove bindings.
  "
  (let [modal (hs.hotkey.modal.new [] nil)]
    (each [_ item (ipairs items)]
      (let [{:key key
             :mods mods
             :action action
             :repeat repeat} item
            mods (or mods [])
            action-fn (action->fn action)]
        (if repeat
            (: modal :bind mods key action-fn nil action-fn)
            (: modal :bind mods key nil action-fn))))
    (: modal :enter)
    (fn destroy-bindings
      []
      (when modal
        (: modal :exit)
        (: modal :delete)))))

(fn bind-global-keys
  [items]
  "
  Binds keys to actions globally like pressing cmd + space to open modal menu
  Takes a list of bindings from config.fnl
  Performs side-effect of creating the key binding to a function.
  Returns a function to unbding keys.
  "
  (map
   (fn [item]
     (let [{:key key} item
           mods (or item.mods [])
           action-fn (action->fn item.action)]
       (if (contains? :hyper mods)
           (hyper.bind key action-fn)
           (let [binding (hs.hotkey.bind mods key action-fn)]
             (fn unbind
               []
               (: binding :delete))))))
   items))

(fn unbind-global-keys
  [bindings]
  "
  Takes a list of functions to remove a binding created by bind-global-keys
  Performs a side effect to remove binding.
  Returns nil
  "
  (each [_ unbind (ipairs bindings)]
    (unbind)))

(fn init
  [config]
  "
  Initializes our key bindings by binding the global keys
  Creates a list of unbind functions for global keys
  Returns a cleanup function to unbind all global key bindings
  "
  (let [keys (or config.keys [])
        bindings (bind-global-keys keys)]
    (fn cleanup
      []
      (unbind-global-keys bindings))))

{:init       init
 :action->fn action->fn
 :bind-keys  bind-keys
 :do-action  do-action}
