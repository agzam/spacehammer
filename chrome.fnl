(require-macros :lib.macros)

;; setting conflicting Cmd+L (jump to address bar) keybinding to Cmd+Shift+L
(fn open-location
  []
  (when-let [app (: (hs.window.focusedWindow) :application)]
            (: app :selectMenuItem ["File" "Open Location…"])))

(fn prev-tab
  []
  (hs.eventtap.keyStroke [:cmd :shift] "["))

(fn next-tab
  []
  (hs.eventtap.keyStroke [:cmd :shift] "]"))

{:open-location open-location
 :prev-tab prev-tab
 :next-tab next-tab}
