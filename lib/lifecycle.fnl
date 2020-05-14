;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

(local {:do-action do-action} (require :lib.bind))
(local log (hs.logger.new "lifecycle.fnl" "debug"))


"
Functions for calling lifecycle methods of config.fnl local app configuration or
lifecycle methods assigned to a specific modal menu in config.fnl.
{:key \"emacs\"
 :launch (fn [] (hs.alert \"Launched emacs\"))
 :activate (fn [] (hs.alert \"Entered emacs\"))
 :deactivate (fn [] (hs.alert \"Leave emacs\"))
 :exit (fn [] (hs.alert \"Closed emacs\"))}
Meant for internal use only.
"

(fn do-method
  [obj method-name]
  "
  Takes a app menu table from config.fnl
  Calls the lifecycle function if a function instance or resolves it to an
  action if an action string was provided like \"lib.lifecycle:do-method\"
  Takes a config.fnl app table and a method name string to try and call.
  Returns the return value of calling the provided lifecycle function.
  "
  (let [method (. obj method-name)]
    (match (type method)
      :function (method obj)
      :string (do-action method [obj])
      _       (do
                (log.wf "Could not call lifecycle method %s on %s"
                        method-name
                        obj)))))

(fn activate-app
  [menu]
  "Calls :activate method on an app in config.fnl when focused on by user"
  (when (and menu menu.activate)
    (do-method menu :activate)))

(fn close-app
  [menu]
  "Calls the :close method on an app in config.fnl when closed by the user"
  (when (and menu menu.close)
    (do-method menu :close)))

(fn deactivate-app
  [menu]
  "Calls the :deactivate method on a config.fnl app when user blurs the app"
  (when (and menu menu.deactivate)
    (do-method menu :deactivate)))

(fn enter-menu
  [menu]
  "Calls the :enter lifecycle method on a modal menu table in config.fnl"
  (when (and menu menu.enter)
    (do-method menu :enter)))

(fn exit-menu
  [menu]
  "Calls the :exit lifecycle method on a modal menu table defined in config.fnl"
  (when (and menu menu.exit)
    (do-method menu :exit)))

(fn launch-app
  [menu]
  "Calls the :launch app table in config.fnl when user opens the app."
  (when (and menu menu.launch)
    (do-method menu :launch)))

{:activate-app   activate-app
 :close-app      close-app
 :deactivate-app deactivate-app
 :enter-menu     enter-menu
 :exit-menu      exit-menu
 :launch-app     launch-app}
