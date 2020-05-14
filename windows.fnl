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

(local {:filter    filter
        :get-in    get-in
        :count     count
        :concat    concat
        :contains? contains?
        :map       map
        :for-each  for-each} (require :lib.functional))
(local {:global-filter global-filter} (require :lib.utils))
(local {:atom   atom
        :deref  deref
        :swap!  swap!
        :reset! reset!} (require :lib.atom))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; History
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(global history {})

(fn history.push
  [self]
  "
  Append current window frame geometry to history.
  self refers to history table instance
  "
  (let [win (hs.window.focusedWindow)
        id (: win :id)
        tbl (. self id)]
    (when win
      (when (= (type tbl) :nil)
        (tset self id []))
      (when tbl
        (let [last-el (. tbl (length tbl))]
          (when (~= last-el (: win :frame))
            (table.insert tbl (: win :frame))))))))

(fn history.pop
  [self]
  "
  Go back to previous window frame geometry in history.
  self refers to history table instance
  "
  (let [win (hs.window.focusedWindow)
        id (: win :id)
        tbl (. self id)]
    (when (and win tbl)
      (let [el (table.remove tbl)
            num-of-undos (length tbl)]
        (if el
            (do
              (: win :setFrame el)
              (when (< 0 num-of-undos)
                (alert (.. num-of-undos " undo steps available"))))
            (alert "nothing to undo"))))))

(fn undo
  []
  (: history :pop))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Shared Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn highlight-active-window
  []
  (let [rect (hs.drawing.rectangle (: (hs.window.focusedWindow) :frame))]
    (: rect :setStrokeColor {:red 1 :blue 0 :green 1 :alpha 1})
    (: rect :setStrokeWidth 5)
    (: rect :setFill false)
    (: rect :show)
    (hs.timer.doAfter .3 (fn [] (: rect :delete)))))

(fn maximize-window-frame
  []
  (: history :push)
  (: (hs.window.focusedWindow) :maximize 0)
  (highlight-active-window))

(fn center-window-frame
  []
  (: history :push)
  (let [win (hs.window.focusedWindow)]
    (: win :maximize 0)
    (hs.grid.resizeWindowThinner win)
    (hs.grid.resizeWindowShorter win)
    (: win :centerOnScreen))
  (highlight-active-window))

(fn activate-app
  [app-name]
  (hs.application.launchOrFocus app-name)
  (let [app (hs.application.find app-name)]
    (when app
      (: app :activate)
      (hs.timer.doAfter .05 highlight-active-window)
      (: app :unhide))))

(fn set-mouse-cursor-at
  [app-title]
  (let [sf (: (: (hs.application.find app-title) :focusedWindow) :frame)
        desired-point (hs.geometry.point (- (+ sf._x sf._w)
                                            (/ sf._w  2))
                                         (- (+ sf._y sf._h)
                                            (/ sf._h 2)))]
    (hs.mouse.setAbsolutePosition desired-point)))

(fn show-grid
  []
  (: history :push)
  (hs.grid.show))

(fn jump-to-last-window
  []
  (-> (global-filter)
      (: :getWindows hs.window.filter.sortByFocusedLast)
      (. 2)
      (: :focus)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Jumping Windows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn jump-window
  [arrow]
  "
  Navigate to the window nearest the current active window
  For instance if you open up emacs to the left of a web browser, activate
  emacs, then run (jump-window :l) hammerspoon will move active focus
  to the browser.
  Takes an arrow like :h :j :k :l to support vim key bindings.
  Performs side effects
  Returns nil
  "
  (let [dir {:h "West" :j "South" :k "North" :l "East"}
        space (. (hs.window.focusedWindow) :filter :defaultCurrentSpace)
        fn-name (.. :focusWindow (. dir arrow))]
    (: space fn-name nil true true)
    (highlight-active-window)))

(fn jump-window-left
  []
  (jump-window :h))

(fn jump-window-above
  []
  (jump-window :j))

(fn jump-window-below
  []
  (jump-window :k))

(fn jump-window-right
  []
  (jump-window :l))

(fn allowed-app?
  [window]
  (if (: window :isStandard)
      true
      false))

(fn jump []
  "
  Displays hammerspoon's window jump UI
  "
  (let [wns (->> (hs.window.allWindows)
                 (filter allowed-app?))]
    (hs.hints.windowHints wns nil true)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Movement\Resizing Constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local
 arrow-map
 {:k {:half [0  0  1 .5] :movement [  0 -20] :complement :h :resize "Shorter"}
  :j {:half [0 .5  1 .5] :movement [  0  20] :complement :l :resize "Taller"}
  :h {:half [0  0 .5  1] :movement [-20   0] :complement :j :resize "Thinner"}
  :l {:half [.5 0 .5  1] :movement [ 20   0] :complement :k :resize "Wider"}})

(fn grid
  [method direction]
  "
  Moves, expands, or shrinks a the active window by the next grid dimension
  Grid settings are specified in config.fnl.
  "
  (let [fn-name (.. method direction)
        f (. hs.grid fn-name)]
    (f (hs.window.focusedWindow))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Resize window by half
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn rect
  [rct]
  "
  Change a window's rect geometry which includes x, y, width, and height
  Takes a rectangle table
  Performs side-effects to move\resize the active window and update history.
  Returns nil
  "
  (: history :push)
  (let [win (hs.window.focusedWindow)]
    (when win (: win :move rct))))

(fn resize-window-halve
  [arrow]
  "
  Resize a window by half the grid dimensions specified in config.fnl.
  Takes an :h :j :k or :l arrow
  Performs a side effect to resize the active window's frame rect
  Returns nil
  "
  (: history :push)
  (rect (. arrow-map arrow :half)))

(fn resize-half-left
  []
  (resize-window-halve :h))

(fn resize-half-right
  []
  (resize-window-halve :l))

(fn resize-half-top
  []
  (resize-window-halve :k))

(fn resize-half-bottom
  []
  (resize-window-halve :j))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Resize window by increments
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn resize-by-increment
  [arrow]
  "
  Resize the active window by the next window increment
  Let's say we make the grid dimensions 4x4 and we place a window in the 1x1
  meaning first column in the first row.
  We then resize an increment right. The dimensions would now be 2x1

  Takes an arrow like :h :j :k :l
  Performs a side-effect to resize the current window to the next grid increment
  Returns nil
  "
  (let [directions {:h "Left"
                    :j "Down"
                    :k "Up"
                    :l "Right"}]
    (: history :push)
    (when (or (= arrow :h) (= arrow :l))
      (hs.grid.resizeWindowThinner (hs.window.focusedWindow)))
    (when (or (= arrow :j) (= arrow :k))
      (hs.grid.resizeWindowShorter (hs.window.focusedWindow)))
    (grid :pushWindow (. directions arrow))))

(fn resize-inc-left
  []
  (resize-by-increment :h))

(fn resize-inc-bottom
  []
  (resize-by-increment :j))

(fn resize-inc-top
  []
  (resize-by-increment :k))

(fn resize-inc-right
  []
  (resize-by-increment :l))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Resize windows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn resize-window
  [arrow]
  "
  Resizes a window against the grid specifed in config.fnl
  Takes an arrow string like :h :k :j :l
  Performs a side effect to resize the current window.
  Returns nil
  "
  (: history :push)
  ;; hs.grid.resizeWindowShorter/Taller/Thinner/Wider
  (grid :resizeWindow (. arrow-map arrow :resize)))

(fn resize-left
  []
  (resize-window :h))

(fn resize-up
  []
  (resize-window :j))

(fn resize-down
  []
  (resize-window :k))

(fn resize-right
  []
  (resize-window :l))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Move to screen directions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn move-to-screen
  [screen]
  "Moves current window onto given hs.screen instance"
  (let [w (hs.window.focusedWindow)]
    (: w :moveToScreen screen)))

(fn move-screen
  [method]
  "
  Moves a window to the display in the specified direction
  :north ^  :south v :east -> :west <-
  Takes a method name of the hammer spoon window instance.
  You probably will not be using this function directly.
  Performs a side effect that will move a window the next screen in specified
  direction.
  Returns nil
  "
  (let [window (hs.window.focusedWindow)]
    (: window method nil true)))

(fn move-north
  []
  (move-screen :moveOneScreenNorth))

(fn move-south
  []
  (move-screen :moveOneScreenSouth))

(fn move-east
  []
  (move-screen :moveOneScreenEast))

(fn move-west
  []
  (move-screen :moveOneScreenWest))

(local canvas (require :hs.canvas))
(local screen-number-canvases (atom []))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Move to screen by number
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn show-display-number
  [idx screen]
  "Shows a big number at the corner of hs.screen.
   To be used as for multi-monitor setups, to easily identify index of each
   screen."
  (let [cs        (canvas.new {})
        font-size (/ (. (: screen :frame) :w) 10)]
    (swap! screen-number-canvases (fn [t] (concat t [cs])))
    (doto cs
      (: :frame (: screen :frame))
      (: :appendElements
         [{:action     :fill
           :type       :text
           :frame      {:x "0.93" :y 0 :h "1" :w "1"}
           :text       (hs.styledtext.new
                        idx
                        {:font  {:size font-size}
                         :color {:red 1 :green 0.5 :blue 0 :alpha 1}})
           :withShadow true}])
      (: :show))))

(fn show-display-numbers
  [screens]
  "Shows big number at the corner of each screen.
   To be used as for multi-monitor setups, to easily identify index of each screen."
  (let [ss (hs.screen.allScreens)]
    (when (< 1 (count ss))
      (each [idx display (ipairs (hs.screen.allScreens))]
        (show-display-number idx display)))))

(fn hide-display-numbers
  []
  "Hides big numbers at the corner of each screen that are used for guidance in
   multi-monitor setups."
  (for-each
   (fn [c] (: c :delete .4))
   (deref screen-number-canvases))
  (reset! screen-number-canvases []))

(fn monitor-item
  [screen i]
  "
  Creates a menu item to move the frontMost window to the specified screen index
  Takes a hs.screen instance and an index integer
  Returns a table-map to add to a config.fnl modal menu
  "
  {:title (.. "Monitor " i)
   :key (tostring i)
   :group :monitor
   :action (fn []
             (when screen
               (move-to-screen screen)))})

(fn remove-monitor-items
  [menu]
  "
  Removes the monitor items from a menu
  Takes a menu table-map
  Mutates the menu object to remove items with :group :monitor flags
  Returns mutated table-map
  "
  (->> menu.items
       (filter #(not (= (. $ :group) :monitor)))
       (tset menu :items))
  menu)

(fn add-monitor-items
  [menu screens]
  "
  Update a menu by adding an item for each connected monitor
  Takes a menu table-map and a table-list of hs.screens
  Mutates the menu.items by adding items for each monitor
  Returns mutated modal menu table-map
  "
  (->> screens
       (map monitor-item)
       (concat menu.items)
       (tset menu :items))
  menu)

(fn enter-window-menu
  [menu]
  "
  Handler that can be used when entering the windows menu
  Takes modal menu table-map
  - Hides any previous display numbers
  - Shows display numbers at top right of each screen
  - Removes previous monitor items if any were added
  - Adds monitor items based on currently connected monitors
  Returns mutated modal menu table-map for threading or chaining
  "
  (let [screens (hs.screen.allScreens)]
    (hide-display-numbers)
    (show-display-numbers screens)
    (remove-monitor-items menu)
    (add-monitor-items menu screens))
  menu)

(fn exit-window-menu
  [menu]
  "
  Handler that can be used when exiting the windows menu
  - Removes previous monitor items if any were added
  Returns mutated modal menu table-map for threading or chaining
  "
  (hide-display-numbers)
  menu)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn init
  [config]
  "
  Initializes the windows module
  Performs side effects:
  - Set grid margins from config.fnl like {:grid {:margins [10 10]}}
  - Set the grid dimensions from config.fnl like {:grid {:size \"3x2\"}}
  "
  (hs.grid.setMargins (or (get-in [:grid :margins] config) [0 0]))
  (hs.grid.setGrid (or (get-in [:grid :size] config) "3x2")))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{:activate-app            activate-app
 :center-window-frame     center-window-frame
 :enter-window-menu       enter-window-menu
 :exit-window-menu        exit-window-menu
 :hide-display-numbers    hide-display-numbers
 :highlight-active-window highlight-active-window
 :init                    init
 :jump                    jump
 :jump-to-last-window     jump-to-last-window
 :jump-window-above       jump-window-above
 :jump-window-below       jump-window-below
 :jump-window-left        jump-window-left
 :jump-window-right       jump-window-right
 :maximize-window-frame   maximize-window-frame
 :move-east               move-east
 :move-north              move-north
 :move-south              move-south
 :move-to-screen          move-to-screen
 :move-west               move-west
 :rect                    rect
 :resize-down             resize-down
 :resize-half-bottom      resize-half-bottom
 :resize-half-left        resize-half-left
 :resize-half-right       resize-half-right
 :resize-half-top         resize-half-top
 :resize-inc-bottom       resize-inc-bottom
 :resize-inc-left         resize-inc-left
 :resize-inc-right        resize-inc-right
 :resize-inc-top          resize-inc-top
 :resize-left             resize-left
 :resize-right            resize-right
 :resize-up               resize-up
 :set-mouse-cursor-at     set-mouse-cursor-at
 :show-display-numbers    show-display-numbers
 :show-grid               show-grid
 :undo-action             undo}
