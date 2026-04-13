(local hhtwm (require :hhtwm))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Swap Windows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn swap-window
  [arrow]
  "
  Swap window using hhtwm.
  "
  (let [dir {:h "west" :j "south" :k "north" :l "east"}
        win (hs.window.focusedWindow)]
    (hhtwm.swapInDirection win (. dir arrow))))

(fn swap-window-left
  []
  (swap-window :h))

(fn swap-window-above
  []
  (swap-window :j))

(fn swap-window-below
  []
  (swap-window :k))

(fn swap-window-right
  []
  (swap-window :l))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Resize layout
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn resize-layout-left
  []
  (hhtwm.resizeLayout "thinner"))

(fn resize-layout-right
  []
  (hhtwm.resizeLayout "wider"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Spaces
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (fn throw-window
;;   [index]
;;   "
;;   Throw window to space using hhtwm
;;   "
;;   (let [win (hs.window.focusedWindow)]
;;     (hhtwm.throwToSpace win index)))

;; (fn throw-window1
;;   []
;;   (throw-window 1))

;; (fn throw-window2
;;   []
;;   (throw-window 2))

;; (fn throw-window3
;;   []
;;   (throw-window 3))

;; (fn throw-window4
;;   []
;;   (throw-window 4))

;; (fn throw-window5
;;   []
;;   (throw-window 5))

;; (fn throw-window6
;;   []
;;   (throw-window 6))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Filtering
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tset hhtwm :filters
      [{:app "Emacs" :title "edit" :tile false}
       {:app "Emacs" :title "capture" :tile false}])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Layout
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn init
  [config]
  "
  Initializes the tiling module
  Performs side effects:
  - Set layout as the main window comes to the right half of current display
  - Start tiling
  "
  (hhtwm.setLayout "main-right")
  (hhtwm.start))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Export
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{: hhtwm
 : swap-window-above
 : swap-window-below
 : swap-window-left
 : swap-window-right
 : resize-layout-left
 : resize-layout-right
 : init
 ;; : throw-window1
 ;; : throw-window2
 ;; : throw-window3
 ;; : throw-window4
 ;; : throw-window5
 ;; : throw-window6
 }
