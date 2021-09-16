(local {: global-filter} (require :lib.utils))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; App switcher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn calc-thumbnail-size
  []
  "
  Calculates the height of thumbnail in pixels based on the screen size
  @TODO Make this advisable when #102 lands
  "
  (let [screen (hs.screen.mainScreen)
        {: h} (: screen :currentMode)]
    (/ h 2)))

(fn init
  [config]
  (global switcher
          (hs.window.switcher.new
           (or (?. config :modules :switcher :filter) (global-filter))
           {:textSize 12
            :showTitles false
            :showThumbnails false
            :showSelectedTitle false
            :selectedThumbnailSize (calc-thumbnail-size)
            :backgroundColor [0 0 0 0]})))

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

{: init
 : prev-app
 : next-app}
