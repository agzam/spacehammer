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

(fn m-key [key]
  "
  Simulates pressing a multimedia key on a keyboard
  Takes the key string and simulates pressing it for 5 ms then relesing it.
  Side effectful.
  Returns nil
  "
  (: (hs.eventtap.event.newSystemKeyEvent (string.upper key) true) :post)
  (hs.timer.usleep 5)
  (: (hs.eventtap.event.newSystemKeyEvent (string.upper key) false) :post))

(fn play-or-pause
 []
 "
 Simulate pressing the play\\pause keyboard key
 "
 (m-key :play))

(fn prev-track
 []
 "
 Simulate pressing the previous track keyboard key
 "
 (m-key :previous))

(fn next-track
 []
 "
 Simulate pressing the next track keyboard key
 "
 (m-key :next))

(fn volume-up
 []
 "
 Simulate pressing the volume up key
 "
 (m-key :sound_up))

(fn volume-down
 []
 "
 Simulate pressing the volume down key
 "
 (m-key :sound_down))

{:play-or-pause play-or-pause
 :prev-track prev-track
 :next-track next-track
 :volume-up volume-up
 :volume-down volume-down}
