(local atom (require :lib.atom))
(local {: call-when
        : contains?
        : eq?
        : filter
        : find
        : get-in
        : has-some?
        : map
        : noop
        : some} (require :lib.functional))
(local statemachine (require :lib.statemachine))
(local {:bind-keys bind-keys} (require :lib.bind))
(local log (hs.logger.new "vim.fnl" "debug"))

"
Create a vim mode for any text editor!
- Modal editing like NORMAL, VISUAL, and INSERT mode.
- vim key navigation like hjkl
- Displays a box to display which mode you are in
- Largely experimental

TODO: Create another state machine system to support key chords for bindings
      like gg -> scroll to top of document.
      - Should work a lot like the menu modal state machine where you can
        endlessly enter recursive submenus
"

(var fsm nil)

;; Box shapes for displaying current mode
(local shape {:x 900
              :y 900
              :h 40
              :w 180})
(local text (hs.drawing.text shape ""))
(local box (hs.drawing.rectangle shape))

(: text :setBehaviorByLabels [:canJoinAllSpaces
                              :transient])

(: box :setBehaviorByLabels [:canJoinAllSpaces
                             :transient])

(: text :setLevel :overlay)
(: box :setLevel :overlay)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Action dispatch functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn disable
  []
  (when fsm
    (fsm.send :disable)))

(fn enable
  []
  (when fsm
    (fsm.send :enable)))

(fn normal
  []
  (when fsm
    (fsm.send :normal)))

(fn visual
  []
  (when fsm
    (fsm.send :visual)))

(fn insert
  []
  (when fsm
    (fsm.send :insert)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helpers, Utils & Config
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var ignore-fx false)

(fn keystroke
  [target-mods target-key]
  (set ignore-fx true)
  (hs.eventtap.keyStroke (or target-mods []) target-key 10000)
  (hs.timer.doAfter 0.1 (fn [] (set ignore-fx false))))

(fn key-fn
  [target-mods target-key]
  (fn [] (keystroke target-mods target-key)))

(local bindings
       {:normal [{:key :h
                  :action (key-fn [] :left)
                  :repeat true}
                 {:key :j
                  :action (key-fn [] :down)
                  :repeat :true}
                 {:key :k
                  :action (key-fn [] :up)
                  :repeat true}
                 {:key :l
                  :action (key-fn [] :right)
                  :repeat true}
                 {:mods [:shift]
                  :key :i
                  :action (fn []
                            (insert)
                            (keystroke [:ctrl] :a))}
                 {:key :i
                  :action insert}
                 {:key :a
                  :action (fn []
                            (insert)
                            (keystroke nil :right))}
                 {:mods [:shift]
                  :key :a
                  :action (fn []
                            (insert)
                            (keystroke [:ctrl] :e))}
                 {:key :v
                  :action visual}
                 {:mods [:shift]
                  :key :v
                  :action (fn []
                            (keystroke [:cmd] :left)
                            (keystroke [:shift :cmd] :right)
                            (visual))}
                 {:key :/
                  :action (key-fn [:cmd] :f)}
                 {:key :x
                  :action (key-fn nil :forwarddelete)}
                 {:key :o
                  :action (fn []
                            (keystroke [:cmd] :right)
                            (keystroke [:alt] :return)
                            (insert))}
                 {:mods [:shift]
                  :key :o
                  :action (fn []
                            (keystroke [:cmd] :left)
                            (keystroke [:alt] :return)
                            (keystroke nil :left)
                            (insert))}
                 {:key :p
                  :action (key-fn [:cmd] :v)}
                 {:key :0
                  :action (key-fn [:cmd] :left)}
                 {:mods [:shift]
                  :key :4
                  :action (key-fn [:cmd] :right)}
                 {:mods [:ctrl]
                  :key :u
                  :action (key-fn nil :pageup)}
                 {:mods [:ctrl]
                  :key :d
                  :action (key-fn nil :pagedown)}
                 {:mods [:shift]
                  :key :g
                  :action (key-fn [:cmd] :down)}
                 {:key :b
                  :action (key-fn [:alt] :left)}
                 {:key :w
                  :action (fn []
                            (keystroke [:alt] :right)
                            (keystroke nil :right))}
                 {:key :u
                  :action (key-fn [:cmd] :z)}
                 {:mods [:ctrl]
                  :key :r
                  :action (key-fn [:cmd :shift] :z)}
                 {:key :c
                  :action (fn []
                            (keystroke [] :forwarddelete)
                            (insert))}
                 {:mods [:shift]
                  :key :d
                  :action (fn []
                            (keystroke [:cmd] :left)
                            (keystroke [:shift :cmd] :right)
                            (keystroke nil :delete)
                            (keystroke nil :delete))}
                 {:mods [:shift]
                  :key :c
                  :action (fn []
                            (keystroke [:cmd] :left)
                            (keystroke [:shift :cmd] :right)
                            (keystroke nil :delete)
                            (insert))}
                 {:key :s
                  :action (fn []
                            (keystroke nil :forwarddelete)
                            (insert))}
                 {:mods [:ctrl]
                  :key :h
                  :action "windows:jump-window-left"}
                 {:mods [:ctrl]
                  :key :j
                  :action "windows:jump-window-below"}
                 {:mods [:ctrl]
                  :key :k
                  :action "windows:jump-window-above"}
                 {:mods [:ctrl]
                  :key :l
                  :action "windows:jump-window-right"}]
        :insert [{:key :ESCAPE
                  :action normal}]
        :visual [{:key :ESCAPE
                  :action (fn []
                            (keystroke nil :left)
                            (normal))}
                 {:key :h
                  :action (key-fn [:shift] :left)}
                 {:key :j
                  :action (key-fn [:shift] :down)}
                 {:key :k
                  :action (key-fn [:shift] :up)}
                 {:key :l
                  :action (key-fn [:shift] :right)}
                 {:key :y
                  :action (key-fn [:cmd]   :c)}
                 {:key :x
                  :action (key-fn nil :delete)}
                 {:key :c
                  :action (fn []
                            (keystroke [] :delete)
                            (insert))}
                 {:key :b
                  :action (key-fn [:shift :alt] :left)}
                 {:key :w
                  :action (fn []
                            (keystroke [:shift :alt] :right)
                            (keystroke [:shift] :right))}
                 {:key :0
                  :action (key-fn [:shift :cmd] :left)}
                 {:mods [:shift]
                  :key :4
                  :action (key-fn [:shift :cmd] :right)}]})

(fn create-screen-watcher
  [f]
  (let [watcher (hs.screen.watcher.newWithActiveScreen f)]
    (: watcher :start)
    (fn destroy []
      (: watcher :stop))))

(fn state-box
  [label]
  (let [frame (: (hs.screen.mainScreen) :fullFrame)
        x frame.x
        y frame.y
        width frame.w
        height frame.h
        coords {:x (+ x (- width shape.w))
                :y (+ y (- height shape.h))
                :h shape.h
                :w shape.w}]
    (: box :setFillColor {:hex "#000"
                          :alpha 0.8})
    (: box :setFill true)
    (: text :setTextColor {:hex "#FFF"
                           :alpha 1.0})
    (: text :setFrame coords)
    (: box :setFrame coords)
    (: text :setText label)
    (if (= label :Normal)
        (: text :setTextColor {:hex "#999"
                               :alpha 0.8})
        (= label :Insert)
        (: text :setTextColor {:hex "#0F0"
                               :alpha 0.8})
        (= label :Visual)
        (: text :setTextColor {:hex "#F0F"
                               :alpha 0.8}))
    (: text :setTextStyle {:alignment :center})
    (: box :show)
    (: text :show))
  box)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Side Effects
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn enter-normal-mode
  [state extra]
  (state-box "Normal")
  (bind-keys bindings.normal))

(fn enter-insert-mode
  [state extra]
  (state-box "Insert")
  (bind-keys bindings.insert))

(fn enter-visual-mode
  [state extra]
  (state-box "Visual")
  (bind-keys bindings.visual))

(fn disable-vim-mode
  [state extra]
  (: box :hide)
  (: text :hide))

(local vim-effect
       (statemachine.effect-handler
        {:enter-normal-mode enter-normal-mode
         :enter-insert-mode enter-insert-mode
         :enter-visual-mode enter-visual-mode
         :disable-vim-mode disable-vim-mode}))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Transitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn disabled->normal
  [state data]
  (when (get-in [:context :config :vim :enabled] state)
    {:state {:current-state :normal
             :context state.context}
     :effect :enter-normal-mode}))

(fn normal->insert
  [state data]
  {:state {:current-state :insert
           :context state.context}
   :effect :enter-insert-mode})

(fn normal->visual
  [state data]
  {:state {:current-state :visual
           :context state.context}
   :effect :enter-visual-mode})

(fn ->disabled
  [state data]
  {:state {:current-state :disabled
           :context state.context}
   :effect :disable-vim-mode})

(fn insert->normal
  [state data]
  {:state {:current-state :normal
           :context state.context}
   :effect :enter-normal-mode})

(fn visual->normal
  [state data]
  {:state {:current-state :normal
           :context state.context}
   :effect :enter-normal-mode})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; States
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(local states
       {:disabled {:enable  disabled->normal}
        :normal   {:insert  normal->insert
                   :visual  normal->visual
                   :disable ->disabled}
        :insert   {:normal  insert->normal
                   :disable ->disabled}
        :visual   {:normal  visual->normal
                   :disable ->disabled}})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Watchers & Logging
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn log-updates
  [fsm]
  (atom.add-watch fsm.state :logger
                  (fn [state]
                    (log.f "Vim mode: %s" state.current-state))))

(fn watch-screen
  [fsm active-screen-changed]
  (let [state (atom.deref fsm.state)]
    (when (~= state.current-state :disabled)
      (state-box state.current-state))))

;; (fn log-key
;;   [event]
;;   (let [key-code (: event :getKeyCode)
;;         flags (: event :getFlags)
;;         key-char (. hs.keycodes.map key-code)]
;;     (values false {})))

;; (let [types hs.eventtap.event.types
;;       tap (hs.eventtap.new [types.keyDown]
;;                            log-key)]
;;   (: tap :start))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn init
  [config]
  "
  Initialize vim mode only enables it if {:vim {:enabled true}} is in config.fnl
  Takes config.fnl table
  Performs side-effects:
  - Creates a state machine to track which mode we are in and switch bindings
    accordingly
  - Creates a screen watcher so it can move the mode UI to the currently active
    screen.
  Returns function to cleanup watcher resources
  "
  (let [template {:state {:current-state :disabled
                          :context {:config config}}
                  :states states}
        _fsm (statemachine.new template)
        stop-screen-watcher (create-screen-watcher
                             (partial watch-screen _fsm))]
    (set fsm _fsm)
    (fsm.subscribe vim-effect)
    (log-updates fsm)
    (when (get-in [:vim :enabled] config)
      (enable))
    (fn []
      (stop-screen-watcher))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

{: init
 : disable
 : enable}
