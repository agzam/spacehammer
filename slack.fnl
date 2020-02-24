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

(local windows (require :windows))

"
Slack functions to make complex or less accessible features more vim like!
"

;; Utils

(fn scroll-to-bottom
  []
  (windows.set-mouse-cursor-at :Slack)
  (hs.eventtap.scrollWheel [0 -20000] {}))

(fn add-reaction
  []
  (hs.eventtap.keyStroke [:cmd :shift] "\\"))

(fn prev-element
  []
  (hs.eventtap.keyStroke [:shift] :f6))

(fn next-element
  []
  (hs.eventtap.keyStroke nil :f6))

(fn thread
  []
  "
  Start a thread on the last message. It doesn't always work, because of
  stupid Slack App inconsistency with TabIndexes
  "
  (hs.eventtap.keyStroke [:shift] :f6)
  (hs.eventtap.keyStroke [] :right)
  (hs.eventtap.keyStroke [] :space))

(fn quick-switcher
  []
  (windows.activate-app "/Applications/Slack.app")
  (let [app (hs.application.find :Slack)]
    (when app
      (hs.eventtap.keyStroke [:cmd] :t)
      (: app :unhide))))


;; scroll to prev/next day

(fn prev-day
  []
  (hs.eventtap.keyStroke [:shift] :pageup))

(fn next-day
  []
  (hs.eventtap.keyStroke [:shift] :pagedown))

;; Scrolling functions

(fn scroll-slack
  [dir]
  (windows.set-mouse-cursor-at :Slack)
  (hs.eventtap.scrollWheel [0 dir] {}))

(fn scroll-up
  []
  (scroll-slack -3))

(fn scroll-down
  []
  (scroll-slack 3))


;; History

(fn prev-history
  []
  (hs.eventtap.keyStroke [:cmd] "["))

(fn next-history
  []
  (hs.eventtap.keyStroke [:cmd] "]"))


;; Arrow keys

(fn up
  []
  (hs.eventtap.keyStroke nil :up))

(fn down
  []
  (hs.eventtap.keyStroke nil :down))

{:add-reaction     add-reaction
 :down             down
 :next-day         next-day
 :next-element     next-element
 :next-history     next-history
 :prev-day         prev-day
 :prev-element     prev-element
 :prev-history     prev-history
 :quick-switcher   quick-switcher
 :scroll-down      scroll-down
 :scroll-to-bottom scroll-to-bottom
 :scroll-up        scroll-up
 :thread           thread
 :up               up}
