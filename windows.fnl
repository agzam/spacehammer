(global undo {})

(fn undo.push [self]
  (let [win (hs.window.focusedWindow)
        id (: win :id)
        tbl (. self id)]
    (when win
      (when (= (type tbl) :nil)
        (tset self id []))
      (when tbl
        (let [last-el (. tbl (# tbl))]
          (when (~= last-el (: win :frame))
            (table.insert tbl (: win :frame))))))))

(fn undo.pop [self]
  (let [win (hs.window.focusedWindow)
        id (: win :id)
        tbl (. self id)]
    (when (and win tbl)
      (let [el (table.remove tbl)
            num-of-undos (# tbl)]
        (if el
            (do
              (: win :setFrame el)
              (when (< 0 num-of-undos)
                (alert (.. num-of-undos " undo steps available"))))
            (alert "nothing to undo"))))))

(fn jump-to-last-window [fsm]
  (let [utils (require :utils)]
    (-> (utils.globalFilter)
        (: :getWindows hs.window.filter.sortByFocusedLast)
        (. 2)
        (: :focus))
    (: fsm :toIdle)))

(fn highlight-active-window []
  (let [rect (hs.drawing.rectangle (: (hs.window.focusedWindow) :frame))]
    (: rect :setStrokeColor {:red 1 :blue 0 :green 1 :alpha 1})
    (: rect :setStrokeWidth 5)
    (: rect :setFill false)
    (: rect :show)
    (hs.timer.doAfter .3 (fn [] (: rect :delete)))))

(fn maximize-window-frame [fsm]
  (: undo :push)
  (: (hs.window.focusedWindow) :maximize 0)
  (highlight-active-window)
  (: fsm :toIdle))

(fn center-window-frame [fsm]
  (: undo :push)
  (let [win (hs.window.focusedWindow)]
    (: win :maximize 0)
    (hs.grid.resizeWindowThinner win)
    (hs.grid.resizeWindowShorter win)
    (: win :centerOnScreen))
  (highlight-active-window)
  (when fsm
    (: fsm :toIdle)))

(local
 arrow-map
 {:k {:half [0  0  1 .5] :movement [  0 -20] :complement :h :resize "Shorter"}
  :j {:half [0 .5  1 .5] :movement [  0  20] :complement :l :resize "Taller"}
  :h {:half [0  0 .5  1] :movement [-20   0] :complement :j :resize "Thinner"}
  :l {:half [.5 0 .5  1] :movement [ 20   0] :complement :k :resize "Wider"}})

(fn rect [rct]
  (: undo :push)
  (let [win (hs.window.focusedWindow)]
    (when win (: win :move rct))))

(fn window-jump [modal fsm arrow]
  (let [dir {:h "West" :j "South" :k "North" :l "East"}]
    (: modal :bind [:ctrl]
       arrow
       (fn []
         (let [slf (-> (hs.window.focusedWindow)
                       (. :filter)
                       (. :defaultCurrentSpace))
               fun (->> (. dir arrow)
                        (.. :focusWindow)
                        (. slf))]
           (fun slf nil true true)
           (highlight-active-window))))))

(fn resize-window [modal arrow]
  (let [dir {:h "Left" :j "Down" :k "Up" :l "Right"}]
    ;; screen halves
    (: modal :bind nil arrow
       (fn []
         (: undo :push)
         (rect (. (. arrow-map arrow) :half))))

    ;; hs.grid.pushWindowUp/Down/Left/Right
    (: modal :bind [:alt] arrow
       (fn []
         (: undo :push)
         (when (or (= arrow :h) (= arrow :l))
           (hs.grid.resizeWindowThinner (hs.window.focusedWindow)))
         (when (or (= arrow :j) (= arrow :k))
           (hs.grid.resizeWindowShorter (hs.window.focusedWindow)))
         (let [gridFn (->> (. dir arrow)
                           (.. :pushWindow)
                           (. hs.grid))]
           (gridFn (hs.window.focusedWindow)))))

    ;; hs.grid.resizeWindowShorter/Taller/Thinner/Wider
    (: modal :bind
       [:shift]
       arrow
       (fn []
         (: undo :push)
         (let [dir (-> arrow-map (. arrow) (. :resize))
               gridFn (->> dir (.. :resizeWindow) (. hs.grid))]
           (gridFn (hs.window.focusedWindow)))))))

(hs.grid.setMargins [0 0])
(hs.grid.setGrid "3x2")

(fn show-grid [fsm]
  ;; todo: undo
  (: undo :push)
  (hs.grid.show)
  (: fsm :toIdle))

(fn bind [hotkeyMmodal fsm]
  ;; maximize window
  (: hotkeyMmodal :bind nil :m (partial maximize-window-frame fsm))

  ;; center window
  (: hotkeyMmodal :bind nil :c (partial center-window-frame fsm))

  ;; undo last thing
  (: hotkeyMmodal :bind nil :u (fn [] (: undo :pop)))

  ;; moving/re-sizing windows
  (hs.fnutils.each
   [:h :l :k :j]
   (hs.fnutils.partial resize-window hotkeyMmodal))

  ;; window grid
  (: hotkeyMmodal :bind nil :g (hs.fnutils.partial show-grid fsm))

  ;; jumping between windows
  (hs.fnutils.each
   [:h :l :k :j]
   (hs.fnutils.partial window-jump hotkeyMmodal fsm))

  ;; quick jump to the last window
  (: hotkeyMmodal :bind nil :w
     (hs.fnutils.partial jump-to-last-window fsm))

  ;; moving windows between monitors
  (: hotkeyMmodal :bind nil :p
     (fn []
       ;; todo: undo:push
       (: (hs.window.focusedWindow) :moveOneScreenNorth nil true)))
  (: hotkeyMmodal :bind nil :n
     (fn []
       ;; todo: undo: push
       (: (hs.window.focusedWindow) :moveOneScreenSouth nil true)))
  (: hotkeyMmodal :bind [:shift] :n
     (fn []
       ;; todo: undo: push
       (: (hs.window.focusedWindow) :moveOneScreenWest nil true)))
  (: hotkeyMmodal :bind [:shift] :p
     (fn []
       ;; todo: undo: push
       (: (hs.window.focusedWindow) :moveOneScreenEast nil true))))


(fn activate-app [app-name]
  (hs.application.launchOrFocus app-name)
  (let [app (hs.application.find app-name)]
    (when app
      (: app :activate)
      (hs.timer.doAfter .05 highlight-active-window)
      (: app :unhide))))

(fn set-mouse-cursor-at [app-title]
  (let [sf (: (: (hs.application.find app-title) :focusedWindow) :frame)
        desired-point (hs.geometry.point (- (+ sf._x sf._w)
                                            (/ sf._w  2))
                                         (- (+ sf._y sf._h)
                                            (/ sf._h 2)))]
    (hs.mouse.setAbsolutePosition desired-point)))

(fn add-state [modal]
  (modal.add-state
   :windows
   {:from :*
    :init (fn [self fsm]
            (set self.hotkeyModal (hs.hotkey.modal.new))
            (modal.display-modal-text "cmd + hjkl \t jumping\nhjkl \t\t\t\t halves\nalt + hjkl \t\t increments\nshift + hjkl \t resize\nn, p \t next, prev screen\ng \t\t\t\t\t grid\nm \t\t\t\t maximize\nu \t\t\t\t\t undo")

            (modal.bind
             self
             [:cmd] :space
             (fn [] (: fsm :toMain)))

            (bind self.hotkeyModal fsm)

            (: self.hotkeyModal :enter))}))

{:add-state               add-state
 :activate-app            activate-app
 :set-mouse-cursor-at     set-mouse-cursor-at
 :maximize-window-frame   maximize-window-frame
 :center-window-frame     center-window-frame
 :highlight-active-window highlight-active-window}
