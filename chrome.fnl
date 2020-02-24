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

(require-macros :lib.macros)

;; setting conflicting Cmd+L (jump to address bar) keybinding to Cmd+Shift+L
(fn open-location
  []
  "
  Activate the Chrome > File > Open Location... action which moves focus to the
  address\\search bar.
  Returns nil
  "
  (when-let [app (: (hs.window.focusedWindow) :application)]
            (: app :selectMenuItem ["File" "Open Location…"])))

(fn prev-tab
  []
  "
  Send the key stroke cmd+shift+[ to move to the previous tab.
  This shortcut is shared by a lot of apps in addition to Chrome!.
  "
  (hs.eventtap.keyStroke [:cmd :shift] "["))

(fn next-tab
  []
  "
  Send the key stroke cmd+shift+] to move to the next tab.
  This shortcut is shared by a lot of apps in addition to Chrome!.
  "
  (hs.eventtap.keyStroke [:cmd :shift] "]"))

{:open-location open-location
 :prev-tab prev-tab
 :next-tab next-tab}
