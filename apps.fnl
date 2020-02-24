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

(local {:global-filter global-filter} (require :lib.utils))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; App switcher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local switcher
       (hs.window.switcher.new
        (global-filter)
        {:textSize 12
         :showTitles false
         :showThumbnails false
         :showSelectedTitle false
         :selectedThumbnailSize 800
         :backgroundColor [0 0 0 0]}))

(fn prev-app
  []
  "
  Open the fancy hammerspoon window switcher and move the cursor to the previous
  app.
  Runs side-effects
  Returns nil
  "
  (: switcher :previous))

(fn next-app
  []
  "
  Open the fancy hammerspoon window switcher and move the cursor to next app.
  Runs side-effects
  Returns nil
  "
  (: switcher :next))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{:prev-app                prev-app
 :next-app                next-app}
