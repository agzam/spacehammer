(local ax (require :hs.axuielement))
(local log (hs.logger.new "ewe" "info"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sessions - each edit-with-emacs invocation creates a session
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(var sessions {})
(var session-counter 0)

(fn gen-session-id []
  (set session-counter (+ session-counter 1))
  (.. "ewe-" session-counter "-" (math.floor (* (hs.timer.absoluteTime) 0.000001))))

(fn get-focused-text-element []
  "Get the currently focused UI element via Accessibility API.
   Returns the element if it's a text-editable field with settable AXValue,
   nil otherwise (triggers clipboard fallback)."
  (let [sys (ax.systemWideElement)
        el  (sys:attributeValue :AXFocusedUIElement)]
    (when el
      (let [role     (el:attributeValue :AXRole)
            settable (el:isAttributeSettable :AXValue)]
        ;; only return elements that are text-like AND have a settable value
        (when (and settable
                   (or (= role :AXTextArea)
                       (= role :AXTextField)
                       (= role :AXComboBox)
                       (= role :AXTextView)))
          el)))))

(fn ax-set-value [el text]
  "Set the AXValue on an element. Returns true on success."
  (let [settable (el:isAttributeSettable :AXValue)]
    (when settable
      (el:setAttributeValue :AXValue text)
      true)))

(fn ax-get-app-element [pid]
  "Get the focused text element for an app by PID. Used to re-acquire
   a fresh AX reference in case the original one went stale."
  (let [app (hs.application.applicationForPID (tonumber pid))]
    (when app
      (let [ax-app (ax.applicationElement app)
            el     (ax-app:attributeValue :AXFocusedUIElement)]
        (when (and el (el:isAttributeSettable :AXValue))
          el)))))

(fn escape-elisp-string [s]
  "Escape a string for embedding in an elisp string literal."
  (-> s
      (: :gsub "\\\\" "\\\\\\\\")
      (: :gsub "\"" "\\\\\"")
      (: :gsub "\n" "\\\\n")
      (: :gsub "\r" "\\\\r")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Emacsclient helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn emacsclient-exe []
  "Locate emacsclient executable."
  (let [(output status) (hs.execute "export PATH=$PATH:/opt/homebrew/bin && which emacsclient")
        path (and status (not= output "") (output:gsub "\n$" ""))]
    (if path
        path
        (-> "Emacs"
            hs.application.find
            (: :path)
            (: :gsub "Emacs.app" "bin/emacsclient")))))

(fn run-emacs-fn
  [elisp-fn args]
  "Executes given elisp function in emacsclient. If args table present, passes
   them into the function."
  (let [args-lst (when args (.. " '" (table.concat args " '")))
        run-str  (.. (emacsclient-exe)
                     " -e \"(funcall '" elisp-fn
                     (if args-lst args-lst " &")
                     ")\" &")]
    (io.popen run-str)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Org Capture
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn capture [is-note]
  "Activates org-capture"
  (let [key         (if is-note "\"z\"" "")
        current-app (hs.window.focusedWindow)
        pid         (.. "\"" (current-app:pid) "\" ")
        title       (.. "\"" (current-app:title) "\" ")
        run-str     (..
                     (emacsclient-exe)
                     " -c -F '(quote (name . \"capture\"))'"
                     " -e '(spacehammer-activate-capture-frame "
                     pid title key " )' &")
        timer       (hs.timer.delayed.new .1 (fn [] (io.popen run-str)))]
    (timer:start)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Edit with Emacs - AX-powered version
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn wait-for-clipboard-change [prev-count callback retries]
  "Poll clipboard until changeCount differs from prev-count, then call callback
   with true. If retries exhausted (default 10, i.e. ~500ms), call with false."
  (let [max-retries (or retries 10)
        check (fn check [n]
                (if (not= (hs.pasteboard.changeCount) prev-count)
                    (callback true)
                    (> n max-retries)
                    (callback false)
                    ;; else: try again in 50ms
                    (hs.timer.doAfter 0.05 (fn [] (check (+ n 1))))))]
    (check 1)))

(fn open-emacs-for-session [session-id session had-selection]
  "Open emacsclient for an edit session. Called after clipboard is ready."
  (let [run-str (..
                 (emacsclient-exe)
                 " -e '(spacehammer-edit-with-emacs "
                 "\"" session.pid "\" "
                 "\"" (escape-elisp-string session.title) "\" "
                 "\"" session.screen "\" "
                 "\"" session-id "\" "
                 (if had-selection "t" "nil")
                 " )' &")]
    (io.popen run-str)
    (hs.application.open :Emacs)))

(fn build-session [session-id pid title screen-id ax-el had-selection]
  "Read clipboard and AX state, create session entry, open Emacs."
  (log.i (.. "build-session: " session-id " sel=" (tostring had-selection)
             " ax=" (tostring (not= nil ax-el))))
  (let [selected-text (hs.pasteboard.getContents)
        full-text     (when ax-el (ax-el:attributeValue :AXValue))
        ;; For selection mode with AX: find prefix/suffix anchors
        prefix        (when (and had-selection full-text selected-text)
                        (let [pos (string.find full-text selected-text 1 true)]
                          (when pos
                            (full-text:sub 1 (- pos 1)))))
        suffix        (when (and had-selection full-text selected-text prefix)
                        (let [end-pos (+ (length prefix) (length selected-text))]
                          (full-text:sub (+ end-pos 1))))
        mode          (if ax-el :ax :clipboard)
        session       {:pid           pid
                       :title         title
                       :screen        screen-id
                       :ax-element    ax-el
                       :mode          mode
                       :has-selection had-selection
                       :prefix        prefix
                       :suffix        suffix
                       :original      selected-text}]
    (log.i (.. "session " session-id ": mode=" mode
               " text-len=" (tostring (and selected-text (length selected-text)))))
    (tset sessions session-id session)
    (open-emacs-for-session session-id session had-selection)))

(fn edit-with-emacs []
  "Start an edit-with-emacs session.
   Uses Cmd+C to grab text, then captures AX element for direct write-back.
   Async: waits for clipboard to actually change before proceeding."
  (let [current-win (hs.window.focusedWindow)
        current-app (current-win:application)
        pid         (current-app:pid)
        title       (current-app:title)
        screen-id   (tostring (: (hs.screen.mainScreen) :id))
        session-id  (gen-session-id)
        ax-el       (get-focused-text-element)
        prev-count  (hs.pasteboard.changeCount)]
    ;; Send Cmd+C and wait for clipboard to change
    (hs.eventtap.keyStroke [:cmd] :c)
    (wait-for-clipboard-change prev-count
      (fn [got-selection]
        (if got-selection
            ;; User had text selected - Cmd+C worked
            (build-session session-id pid title screen-id ax-el true)
            ;; Nothing was selected - grab everything with Cmd+A, Cmd+C
            (let [prev2 (hs.pasteboard.changeCount)]
              (hs.eventtap.keyStroke [:cmd] :a)
              (hs.eventtap.keyStroke [:cmd] :c)
              (wait-for-clipboard-change prev2
                (fn [got-all]
                  (if got-all
                      (build-session session-id pid title screen-id ax-el false)
                      ;; Last resort: maybe AX has the text directly
                      (let [ax-text (when ax-el (ax-el:attributeValue :AXValue))]
                        (when ax-text
                          (hs.pasteboard.setContents ax-text))
                        (build-session session-id pid title screen-id ax-el false)))))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IPC functions - callable from Emacs via `hs -c`
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn paste-via-clipboard [text pid opts]
  "Put text on clipboard, activate app, paste it.
   opts.then-fn is called after paste completes."
  (let [then-fn (. (or opts {}) :then-fn)]
    (hs.pasteboard.setContents text)
    (let [app (hs.application.applicationForPID (tonumber pid))]
      (when app
        (app:activate)
        (hs.timer.doAfter 0.05
          (fn []
            (hs.eventtap.keyStroke [:cmd] :v)
            (when then-fn
              (hs.timer.doAfter 0.05 then-fn)))))))
  "ok")

(fn session-write-ax [session text]
  "Write text back via AX for a session. For selection sessions, reconstructs
   full value from prefix + edited text + suffix. Re-acquires a fresh AX
   element if the stored one went stale. Returns true on success."
  (let [;; try stored element first, re-acquire if stale
        el (or session.ax-element (ax-get-app-element session.pid))]
    (log.i (.. "write-ax: el=" (tostring (not= nil el))
               " sel=" (tostring session.has-selection)))
    (when el
      ;; update stored ref in case we re-acquired
      (tset session :ax-element el)
      (let [sel? (and session.has-selection session.prefix session.suffix)
            result (if sel?
                       (ax-set-value el (.. session.prefix text session.suffix))
                       (ax-set-value el text))]
        (log.i (.. "write-ax result: " (tostring result)))
        ;; Re-select the replaced portion so the user can see what changed.
        ;; Delay is needed: apps reset AXSelectedTextRange when AXValue changes.
        (when (and result sel?)
          (hs.timer.doAfter 0.1
            (fn []
              (el:setAttributeValue :AXSelectedTextRange
                {:location (length session.prefix) :length (length text)}))))
        result))))

(fn sync-text [session-id text]
  "Push text from Emacs back to the originating app's text field without
   ending the session. Callable from Emacs.

   AX mode: write directly via accessibility (no app switch needed).
   Clipboard mode: switch to app, paste, switch back."
  (let [session (. sessions session-id)]
    (when session
      (if (= session.mode :ax)
          (do
            (session-write-ax session text)
            ;; Always keep clipboard history as a safety net
            (hs.pasteboard.setContents text)
            "ok")
          ;; clipboard fallback
          (if session.has-selection
              ;; paste over preserved visual selection, then return to Emacs
              (do
                (paste-via-clipboard text session.pid
                  {:then-fn (fn [] (hs.application.open :Emacs))})
                "ok")
              ;; no selection: select all, paste, return to Emacs
              (do
                (hs.pasteboard.setContents text)
                (let [app (hs.application.applicationForPID (tonumber session.pid))]
                  (when app
                    (app:activate)
                    (hs.timer.doAfter 0.05
                      (fn []
                        (hs.eventtap.keyStroke [:cmd] :a)
                        (hs.timer.doAfter 0.02
                          (fn []
                            (hs.eventtap.keyStroke [:cmd] :v)
                            (hs.timer.doAfter 0.1
                              (fn [] (hs.application.open :Emacs)))))))))
                "ok"))))))

(fn finish-session [session-id text]
  "Finish editing: write final text to originating app and end session.
   Callable from Emacs.

   AX mode: write directly, then activate the app.
   Clipboard mode: paste via clipboard."
  (let [session (. sessions session-id)]
    (when session
      (if (= session.mode :ax)
          (do
            (session-write-ax session text)
            ;; Always keep clipboard history as a safety net
            (hs.pasteboard.setContents text)
            (let [app (hs.application.applicationForPID (tonumber session.pid))]
              (when app (app:activate))))
          ;; clipboard fallback
          (paste-via-clipboard text session.pid {}))
      ;; clean up session
      (tset sessions session-id nil)
      "ok")))

(fn cancel-session [session-id]
  "Cancel editing: switch back to originating app without modifying text.
   Callable from Emacs."
  (let [session (. sessions session-id)]
    (when session
      (let [app (hs.application.applicationForPID (tonumber session.pid))]
        (when app (app:activate)))
      (tset sessions session-id nil)
      "ok")))

(fn get-session-info [session-id]
  "Return session metadata as a string for Emacs. Callable from Emacs."
  (let [session (. sessions session-id)]
    (if session
        (.. "{:mode \"" session.mode "\""
            " :pid \"" (tostring session.pid) "\""
            " :title \"" (escape-elisp-string session.title) "\""
            " :has-selection " (if session.has-selection "true" "false")
            "}")
        "nil")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Legacy IPC (keep for backward compat)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn switch-to-app [pid]
  "Don't remove! - this is callable from Emacs See: `spacehammer/switch-to-app`
   in spacehammer.el "
  (let [app (hs.application.applicationForPID (tonumber pid))]
    (when app (app:activate))))

(fn switch-to-app-and-paste-from-clipboard [pid]
  "Don't remove! - this is callable from Emacs See:
   `spacehammer/finish-edit-with-emacs` in spacehammer.el."
  (let [app (hs.application.applicationForPID (tonumber pid))]
    (when app
      (app:activate)
      (hs.timer.doAfter
       0.001
       (fn [] (app:selectMenuItem [:Edit :Paste]))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Emacs window management
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn full-screen
  []
  "Switches to current instance of GUI Emacs and makes its frame fullscreen"
  (hs.application.launchOrFocus :Emacs)
  (run-emacs-fn
   (..
    "(lambda ())"
    "(spacemacs/toggle-fullscreen-frame-on)"
    "(spacehammer/fix-frame)")))

(fn vertical-split-with-emacs
  []
  "Creates vertical split with Emacs window sitting next to the current app"
  (let [windows    (require :windows)
        cur-app    (-?> (hs.window.focusedWindow) (: :application) (: :name))
        rect-left  [0  0 .5  1]
        rect-right [.5 0 .5  1]
        elisp      (.. "(lambda ()"
                       " (spacemacs/toggle-fullscreen-frame-off) "
                       " (spacemacs/maximize-horizontally) "
                       " (spacemacs/maximize-vertically))")]
    (run-emacs-fn elisp)
    (hs.timer.doAfter
     .2
     (fn []
       (if (= cur-app :Emacs)
           (do
             (windows.rect rect-left)
             (windows.jump-to-last-window)
             (windows.rect rect-right))
           (do
             (windows.rect rect-right)
             (hs.application.launchOrFocus :Emacs)
             (windows.rect rect-left)))))))

(fn maximize
  []
  "Maximizes Emacs GUI window after a short delay."
  (hs.timer.doAfter
   1.5
   (fn []
     (let [app     (hs.application.find :Emacs)
           windows (require :windows)]
       (when app
         (app:activate)
         (windows.maximize-window-frame))))))

{:capture                          capture
 :edit-with-emacs                  edit-with-emacs
 :full-screen                      full-screen
 :maximize                         maximize
 :note                             (fn [] (capture true))
 :switchToApp                      switch-to-app
 :switchToAppAndPasteFromClipboard switch-to-app-and-paste-from-clipboard
 :vertical-split-with-emacs        vertical-split-with-emacs
 :run-emacs-fn                     run-emacs-fn
 ;; New session-based IPC
 :syncText                         sync-text
 :finishSession                    finish-session
 :cancelSession                    cancel-session
 :getSessionInfo                   get-session-info}
