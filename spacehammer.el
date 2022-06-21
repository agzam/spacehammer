;;; spacehammer.el --- Spacehammer Elisp Helpers -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2022 Ag Ibragimov and Collaborators
;;
;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;; Maintainer: Ag Ibragimov <agzam.ibragimov@gmail.com>
;; Version: 1.0.0
;; Keywords: extensions tools
;; Homepage: https://github.com/agzam/spacehammer
;; Package-Requires: ((emacs "27"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; A few elisp helpers for Spacehammer
;;
;;; Code:

(defun spacehammer-switch-to-app (pid)
  "Switch to app with the given PID."
  (when (and pid (eq system-type 'darwin))
    (call-process (executable-find "hs") nil 0 nil "-c"
                  (concat "require(\"emacs\").switchToApp (\"" pid "\")"))))

(defvar spacehammer-edit-with-emacs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'spacehammer-finish-edit-with-emacs)
    (define-key map (kbd "C-c C-k") #'spacehammer-cancel-edit-with-emacs)
    map))

(define-minor-mode spacehammer-edit-with-emacs-mode
  "Minor mode enabled on buffers opened by spacehammer/edit-by-emacs."
  :init-value nil
  :lighter " editwithemacs"
  :keymap spacehammer-edit-with-emacs-mode-map
  :group 'spacehammer)

(defun spacehammer--turn-on-edit-with-emacs-mode ()
  "Turn on `spacehammer-edit-with-emacs-mode' if the buffer derives from that mode."
  (when (string-match-p "* spacehammer-edit " (buffer-name (current-buffer)))
    (spacehammer-edit-with-emacs-mode t)))

(define-global-minor-mode spacehammer-global-edit-with-emacs-mode
  spacehammer-edit-with-emacs-mode spacehammer--turn-on-edit-with-emacs-mode
  :group 'spacehammer)

(defvar spacehammer-edit-with-emacs-hook nil
  "Hook for when edit-with-emacs buffer gets activated.
Hook function must accept arguments:
- `buffer-name' - the name of the edit buffer
- `pid'         - PID of the app that invoked Edit-with-Emacs
- `title'       - title of the app that invoked Edit-with-Emacs")

(defvar spacehammer-before-finish-edit-with-emacs-hook nil
  "`edit-with-emacs' finished and dedicated buffer and frame about to get deleted.
Hook function must accept arguments:
- `buffer-name' - the name of the edit buffer
- `pid'         - PID of the app that invoked Edit-with-Emacs")

(defvar spacehammer-before-cancel-edit-with-emacs-hook nil
  "`edit-with-emacs' canceled and dedicated buffer and frame about to get deleted.
Hook function must accept arguments:
- `buffer-name' - the name of the edit buffer
- `pid'         - PID of the app that invoked Edit-with-Emacs")

(defun spacehammer-edit-with-emacs (&optional pid title screen)
  "Edit anything with Emacs.
The caller is responsible for setting up the arguments.
PID - process ID of the caller app.
TITLE - title of the window.
SCREEN - the display from which the call initiates, see:
www.hammerspoon.org/docs/hs.screen.html."
  (let* ((buf-name (concat "* spacehammer-edit " title " *"))
         (buffer (get-buffer-create buf-name)))
    (unless (bound-and-true-p spacehammer-global-edit-with-emacs-mode)
      (spacehammer-global-edit-with-emacs-mode +1))
    (with-current-buffer buffer
      (setq-local spacehammer--caller-pid pid)
      (clipboard-yank)
      (deactivate-mark)
      (spacehammer-edit-with-emacs-mode +1))
    (pop-to-buffer buffer)
    (run-hook-with-args 'spacehammer-edit-with-emacs-hook buf-name pid title)))

(defun spacehammer-finish-edit-with-emacs ()
  "When done editing."
  (interactive)
  (when (boundp 'spacehammer--caller-pid)
    (let ((pid (buffer-local-value 'spacehammer--caller-pid (current-buffer))))
      (run-hook-with-args
       'spacehammer-before-finish-edit-with-emacs-hook
       (buffer-name (current-buffer)) pid)
      (clipboard-kill-ring-save (point-min) (point-max))
      (kill-buffer-and-window)
      (call-process
       (executable-find "hs") nil 0 nil "-c"
       (concat "require(\"emacs\").switchToAppAndPasteFromClipboard (\"" pid "\")")))))

(defun spacehammer-cancel-edit-with-emacs ()
  "Burn the useless."
  (interactive)
  (when (boundp 'spacehammer--caller-pid)
    (let ((pid (buffer-local-value 'spacehammer--caller-pid (current-buffer))))
      (run-hook-with-args
       'spacehammer-before-cancel-edit-with-emacs-hook
       (buffer-name (current-buffer)) pid)
      (kill-buffer-and-window)
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
