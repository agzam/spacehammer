(local utils (require :lib.utils))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; App switcher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local switcher
       (hs.window.switcher.new
        (utils.globalFilter)
        {:textSize 12
         :showTitles false
         :showThumbnails false
         :showSelectedTitle false
         :selectedThumbnailSize 800
         :backgroundColor [0 0 0 0]}))

(fn prev-app
  []
  (: switcher :previous))

(fn next-app
  []
  (: switcher :next))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{:prev-app                prev-app
 :next-app                next-app}
