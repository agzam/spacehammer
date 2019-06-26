(fn m-key [key]
  (: (hs.eventtap.event.newSystemKeyEvent (string.upper key) true) :post)
  (hs.timer.usleep 5)
  (: (hs.eventtap.event.newSystemKeyEvent (string.upper key) false) :post))

(fn play-or-pause
 []
 (m-key :play))

(fn prev-track
 []
 (m-key :previous))

(fn next-track
 []
 (m-key :next))

(fn volume-up
 []
 (m-key :sound_up))

(fn volume-down
 []
 (m-key :sound_down))

{:play-or-pause play-or-pause
 :prev-track prev-track
 :next-track next-track
 :volume-up volume-up
 :volume-down volume-down}
