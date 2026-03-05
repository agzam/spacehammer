;;; spacehammer.el --- Spacehammer Elisp Helpers -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2022 Ag Ibragimov and Collaborators
;;
;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;; Maintainer: Ag Ibragimov <agzam.ibragimov@gmail.com>
;; Version: 2.0.0
;; Keywords: extensions tools
;; Homepage: https://github.com/agzam/spacehammer
;; Package-Requires: ((emacs "27"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; Elisp helpers for Spacehammer's edit-with-emacs feature.
;; v2: Session-based architecture with AXUIElement support.
;;
;; Features:
;;   - Multiple simultaneous edit sessions (one per app/text field)
;;   - Direct text injection via macOS Accessibility API (no clipboard clobbering)
;;   - Selection-aware editing (edit just the selected text)
;;   - Live sync: push text to the app without ending the session (C-c C-s)
;;   - Fallback to clipboard-based approach when AX is unavailable
;;
;;; Code:

(require 'cl-seq)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Hammerspoon IPC
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spacehammer--hs-cmd (lua-expr &optional async)
  "Execute LUA-EXPR via the Hammerspoon IPC CLI.
If ASYNC is non-nil, run asynchronously (fire-and-forget)."
  (unless (executable-find "hs")
    (user-error "Hammerspoon IPC command line (hs) not found"))
  (if async
      (call-process (executable-find "hs") nil 0 nil "-c" lua-expr)
    (with-temp-buffer
      (call-process (executable-find "hs") nil t nil "-c" lua-expr)
      (string-trim (buffer-string)))))

(defun spacehammer-switch-to-app (pid)
  "Switch to app with the given PID."
  (when (and pid (eq system-type 'darwin))
    (spacehammer--hs-cmd
     (format "require(\"emacs\").switchToApp(\"%s\")" pid)
     t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Buffer-local session variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar-local spacehammer--caller-pid nil
  "PID of the app that invoked this edit buffer.")

(defvar-local spacehammer--session-id nil
  "Unique session ID linking this buffer to a Hammerspoon session.")

(defvar-local spacehammer--selection-only nil
  "Non-nil if this buffer edits only the selected text, not the whole field.")

(defvar-local spacehammer--caller-title nil
  "Title of the app window that invoked this edit buffer.")

;; Make these survive major-mode changes
(put 'spacehammer--caller-pid 'permanent-local t)
(put 'spacehammer--session-id 'permanent-local t)
(put 'spacehammer--selection-only 'permanent-local t)
(put 'spacehammer--caller-title 'permanent-local t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Minor mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar spacehammer-edit-with-emacs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'spacehammer-finish-edit-with-emacs)
    (define-key map (kbd "C-c C-k") #'spacehammer-cancel-edit-with-emacs)
    (define-key map (kbd "C-c C-s") #'spacehammer-sync-edit-with-emacs)
    map))

(define-minor-mode spacehammer-edit-with-emacs-mode
  "Minor mode enabled on buffers opened by edit-with-emacs.

\\{spacehammer-edit-with-emacs-mode-map}"
  :init-value nil
  :lighter " ewe"
  :keymap spacehammer-edit-with-emacs-mode-map
  :group 'spacehammer)

(defun spacehammer--turn-on-edit-with-emacs-mode ()
  "Turn on `spacehammer-edit-with-emacs-mode' if buffer matches."
  (when (string-match-p "\\* spacehammer-edit " (buffer-name (current-buffer)))
    (spacehammer-edit-with-emacs-mode t)))

(define-global-minor-mode spacehammer-global-edit-with-emacs-mode
  spacehammer-edit-with-emacs-mode spacehammer--turn-on-edit-with-emacs-mode
  :group 'spacehammer)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Hooks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar spacehammer-edit-with-emacs-hook nil
  "Hook for when edit-with-emacs buffer gets activated.

Hook function must accept arguments:
- `buffer-name' - the name of the edit buffer
- `pid'         - PID of the app that invoked Edit-with-Emacs
- `title'       - title of the app that invoked Edit-with-Emacs")

(defvar spacehammer-before-finish-edit-with-emacs-hook nil
  "Fires when editing is done and the dedicated buffer is about be killed.

Hook function must accept arguments:
- `buffer-name' - the name of the edit buffer
- `pid'         - PID of the app that invoked Edit-with-Emacs")

(defvar spacehammer-before-cancel-edit-with-emacs-hook nil
  "Fires when editing is canceled and the dedicated buffer is about to be killed.

Hook function must accept arguments:
- `buffer-name' - the name of the edit buffer
- `pid'         - PID of the app that invoked Edit-with-Emacs")

(defvar spacehammer-after-sync-hook nil
  "Fires after text is synced to the originating app.

Hook function must accept arguments:
- `buffer-name' - the name of the edit buffer
- `session-id'  - the session ID")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spacehammer--find-buffer-by-name-prefix (prefix)
  "Find the first buffer with a name that starts with PREFIX."
  (cl-find-if (lambda (buffer)
                (string-prefix-p prefix (buffer-name buffer)))
              (buffer-list)))

(defun spacehammer--escape-lua-string (s)
  "Escape S for embedding in a Lua string literal (double-quoted)."
  (replace-regexp-in-string
   "\n" "\\\\n"
   (replace-regexp-in-string
    "\r" "\\\\r"
    (replace-regexp-in-string
     "\"" "\\\\\""
     (replace-regexp-in-string "\\\\" "\\\\\\\\" s)))))

(defun spacehammer--buffer-text ()
  "Return the text content of the current buffer as a string."
  (buffer-substring-no-properties (point-min) (point-max)))

(defun spacehammer--key-for (cmd)
  "Return a human-readable key string for CMD in `spacehammer-edit-with-emacs-mode-map'."
  (let ((key (where-is-internal cmd spacehammer-edit-with-emacs-mode-map t)))
    (if key (key-description key) "???")))

(defun spacehammer--set-header-line ()
  "Set `header-line-format' showing available keybindings for the edit session."
  (setq header-line-format
        (list
         (propertize (format " %s " (or spacehammer--caller-title "Edit"))
                     'face '(:weight bold :inherit font-lock-function-name-face))
         (when spacehammer--selection-only
           (propertize " [selection] " 'face '(:inherit warning)))
         (propertize " │ " 'face 'shadow)
         (propertize (spacehammer--key-for #'spacehammer-finish-edit-with-emacs)
                     'face '(:weight bold :inherit success))
         (propertize " submit " 'face 'shadow)
         (propertize "│ " 'face 'shadow)
         (propertize (spacehammer--key-for #'spacehammer-sync-edit-with-emacs)
                     'face '(:weight bold :inherit font-lock-constant-face))
         (propertize " sync " 'face 'shadow)
         (propertize "│ " 'face 'shadow)
         (propertize (spacehammer--key-for #'spacehammer-cancel-edit-with-emacs)
                     'face '(:weight bold :inherit error))
         (propertize " cancel" 'face 'shadow))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Core: edit-with-emacs (v2 - session based)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spacehammer-edit-with-emacs (&optional pid title screen session-id selection-only)
  "Edit text from another app with Emacs.

PID - process ID of the caller app.
TITLE - title of the app window.
SCREEN - display ID from which the call initiates.
SESSION-ID - unique session identifier from Hammerspoon.
SELECTION-ONLY - non-nil if editing only the selected text."
  (let* ((buf-name (format "* spacehammer-edit %s [%s] *"
                           (or title "unknown")
                           (or session-id "legacy")))
         (buffer (or (spacehammer--find-buffer-by-name-prefix
                      (format "* spacehammer-edit %s [%s]" (or title "") (or session-id "")))
                     (get-buffer-create buf-name))))
    (unless (bound-and-true-p spacehammer-global-edit-with-emacs-mode)
      (spacehammer-global-edit-with-emacs-mode +1))
    (with-current-buffer buffer
      (erase-buffer)
      (setq-local spacehammer--caller-pid pid)
      (setq-local spacehammer--caller-title title)
      (setq-local spacehammer--session-id session-id)
      (setq-local spacehammer--selection-only selection-only)
      (clipboard-yank)
      (deactivate-mark)
      (goto-char (point-min))
      (spacehammer-edit-with-emacs-mode +1))
    (pop-to-buffer buffer)
    (run-hook-with-args 'spacehammer-edit-with-emacs-hook buf-name pid title)
    ;; Set header-line after hooks - major mode changes (e.g. markdown-mode)
    ;; in hook functions would otherwise reset it
    (spacehammer--set-header-line)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Sync - push text without ending session
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spacehammer-sync-edit-with-emacs ()
  "Push current buffer text to the originating app without ending the session.
Bound to C-c C-s in edit-with-emacs buffers."
  (interactive)
  (let ((session-id spacehammer--session-id)
        (text (spacehammer--buffer-text)))
    (unless session-id
      (user-error "No session ID - cannot sync (legacy session?)"))
    (let ((escaped (spacehammer--escape-lua-string text)))
      (spacehammer--hs-cmd
       (format "require(\"emacs\").syncText(\"%s\", \"%s\")"
               session-id escaped)
       t))
    (message "Synced to %s" (or spacehammer--caller-pid "app"))
    (run-hook-with-args 'spacehammer-after-sync-hook
                        (buffer-name) session-id)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Finish - push text and end session
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spacehammer-finish-edit-with-emacs ()
  "Finish editing: send text to originating app and close the buffer."
  (interactive)
  (let ((pid spacehammer--caller-pid)
        (session-id spacehammer--session-id)
        (text (spacehammer--buffer-text)))
    (run-hook-with-args
     'spacehammer-before-finish-edit-with-emacs-hook
     (buffer-name (current-buffer)) pid)
    (if session-id
        ;; v2: session-based
        (let ((escaped (spacehammer--escape-lua-string text)))
          (if (one-window-p)
              (kill-buffer)
            (kill-buffer-and-window))
          (spacehammer--hs-cmd
           (format "require(\"emacs\").finishSession(\"%s\", \"%s\")"
                   session-id escaped)
           t))
      ;; Legacy fallback (no session-id)
      (progn
        (clipboard-kill-ring-save (point-min) (point-max))
        (if (one-window-p)
            (kill-buffer)
          (kill-buffer-and-window))
        (spacehammer--hs-cmd
         (format "require(\"emacs\").switchToAppAndPasteFromClipboard(\"%s\")" pid)
         t)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Cancel - abandon edits
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spacehammer-cancel-edit-with-emacs ()
  "Cancel editing: switch back to originating app without modifying text."
  (interactive)
  (let ((pid spacehammer--caller-pid)
        (session-id spacehammer--session-id))
    (run-hook-with-args
     'spacehammer-before-cancel-edit-with-emacs-hook
     (buffer-name (current-buffer)) pid)
    (if (one-window-p)
        (kill-buffer)
      (kill-buffer-and-window))
    (if session-id
        (spacehammer--hs-cmd
         (format "require(\"emacs\").cancelSession(\"%s\")" session-id)
         t)
      (spacehammer-switch-to-app pid))))

;;;; System-wide org capture
(defvar spacehammer--capture-previous-app-pid nil
  "Last app that invokes `spacehammer-activate-capture-frame'.")

(defun spacehammer-activate-capture-frame (&optional pid title keys)
  "Run ‘org-capture’ in capture frame.

PID is a pid of the app (the caller is responsible to set that right)
TITLE is a title of the window (the caller is responsible to set that right)
KEYS is a string associated with a template (will be passed to `org-capture')"
  (setq spacehammer--capture-previous-app-pid pid)
  (select-frame-by-name "capture")
  (set-frame-position nil 400 400)
  (set-frame-size nil 1000 400 t)
  (switch-to-buffer (get-buffer-create "*scratch*"))
  (org-capture nil keys))

(defadvice org-switch-to-buffer-other-window
    (after supress-window-splitting activate)
  "Delete the extra window if we're in a capture frame."
  (if (equal "capture" (frame-parameter nil 'name))
      (delete-other-windows)))

(defadvice org-capture-finalize
    (after delete-capture-frame activate)
  "Advise capture-finalize to close the frame."
  (when (and (equal "capture" (frame-parameter nil 'name))
             (not (eq this-command 'org-capture-refile)))
    (spacehammer-switch-to-app spacehammer--capture-previous-app-pid)
    (delete-frame)))

(defadvice org-capture-refile
    (after delete-capture-frame activate)
  "`org-refile' should close the frame."
  (delete-frame))

(defadvice user-error
    (before before-user-error activate)
  "Failure to select capture template should close the frame."
  (when (eq (buffer-name) "*Org Select*")
    (spacehammer-switch-to-app spacehammer--capture-previous-app-pid)))

(provide 'spacehammer)

;;; spacehammer.el ends here
