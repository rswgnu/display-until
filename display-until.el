;;; display-until.el --- temporarily display windows and frames  -*- lexical-binding: t -*-

;; Copyright (C) 2017 Free Software Foundation, Inc.

;; Author: Robert Weiner
;; Maintainer: emacs-devel@gnu.org
;; Keywords: internal
;; Package: emacs
;; Version: 1.0
;; Orig-Date: 16-Dec-17
;; Last-Mod:  17-Dec-17

;; This file could become part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; (RSW would like this code to be added to core Emacs if it is
;;  acceptable.  Someone else who adds to Emacs regularly would have
;;  to add the NEWS entry, Elisp Manual entry and commit the code.
;;  In that case, the utilty macros and function names could be generalized).

;; This library temporarily displays an existing or new frame topmost in
;; the frame stack.  Then it restores the prior topmost frame as well
;; as any prior visibility status of the temporarily displayed frame,
;; e.g. if it was hidden or iconified.  See the end of the file for
;; sample usage expressions.

;; This library includes the following:
;;   Variables:
;;     display-until-delay - time in seconds to display a temporary frame or
;;       window
;;     display-until-frame-parameters - alist of frame parameters to apply to
;;       any newly created temporarily displayed frame
;;
;;   Display Functions:
;;     display-window-until - given a window and optional buffer, display the
;;       buffer in the window, make the window's frame topmost for
;;       `display-until-delay' seconds, then return the window's frame
;;       to its prior visibility
;;
;;     display-frame-until - given a frame and optional buffer, display the
;;       buffer in the frame's selected window, make the frame topmost for
;;       `display-until-delay' seconds, then return the frame to its prior
;;       visibility
;;
;;   Utility Functions:
;;     display-until-get-frame-by-name - given a name string, return the
;;       matching frame or nil
;;
;;   Utility Macros:
;;     display-until-condition-or-timeout - wait for a boolean condition
;;       or timeout seconds
;;     display-until-thread-condition-or-timeout - run a thread until a boolean
;;;      condition or timeout seconds

;;; Code:

(defvar display-until-delay 0.5
  "Delay time in seconds to display a temporary frame or window.")

(defvar display-until-frame-parameters nil
  "Alist of frame parameters to apply to any newly created temporarily displayed frame.")

(defun display-until-get-frame-by-name (name)
  "Return any frame named NAME, a string, else nil."
  (if (stringp name)
      (catch 'done
	(mapc (lambda (frame)
		(when (string-equal name (get-frame-name frame))
		  (throw 'done frame)))
	      (frame-list))
	nil)
    (error "(display-until-get-frame-by-name): Argument must be a name string, not `%s'" name)))

(defmacro display-until-condition-or-timeout (condition timeout)
  "Wait for the either CONDITION to become non-nil or for TIMEOUT seconds to expire.
CONDITION must be a boolean predicate form.  TIMEOUT must be > zero."
  `(let ((decrement 0.05))
     (setq timeout ,timeout)
     (while (not (or ,condition (<= timeout 0)))
       (sleep-for decrement)
       (setq timeout (- timeout decrement)))))

(defmacro display-until-thread-condition-or-timeout (condition timeout)
  "Wait in a separate thread for either CONDITION to become non-nil or for TIMEOUT seconds to expire.
CONDITION must be a boolean predicate form.  TIMEOUT must be > zero."
  `(make-thread (lambda ()
		  (display-until-condition-or-timeout ,condition ,timeout))))

(defun display-frame-until-condition (frame &optional buffer condition)
  "Display FRAME topmost with optional BUFFER in its selected window until CONDITION or `display-until-delay' seconds.

FRAME may be an existing, even invisible frame, frame name or
nil.  If nil, the selected frame is used.  If FRAME is a string
and no live frame with that name is found, a new one with the
name and any `display-until-frame-parameters' is created.

BUFFER may be an existing buffer or buffer name.

After display, FRAME's prior visibility status is restored.
FRAME's depth in the frame stacking order is not restored."
  (unless frame
    (setq frame (selected-frame)))
  (when (stringp frame)
    (setq frame (or (display-until-get-frame-by-name frame)
		    (make-frame (cons `(name . ,frame)
				      display-until-frame-parameters)))))
  (cond ((not (framep frame))
	 (error "(display-frame-until): First argument must be a frame, not `%s'"
		frame))
	((not (frame-live-p frame))
	 (error "(display-frame-until): First argument must be a live frame, not `%s'"
		frame))
	((and buffer (not (or (bufferp buffer) (and (stringp buffer)
						    (get-buffer buffer)))))
	 (redisplay t)
	 (error "(display-frame-until): Second argument must be an existing buffer or buffer name, not `%s'"
		buffer))
	(t
	 (let ((frame-visible-flag (frame-visible-p frame)))
	   (select-frame frame)
	   (raise-frame frame)
	   (display-buffer (or buffer (window-buffer))
			   (cons 'display-buffer-same-window
				 display-until-frame-parameters) frame)
	   ;; Force redisplay or any changes to frame won't be displayed here.
	   (redisplay t)
	   (if condition
	       (display-until-condition-or-timeout condition display-until-delay)
	     ;; Don't use sit-for here because it can be interrupted early.
	     (sleep-for display-until-delay))
	   (pcase frame-visible-flag
	     ('icon (iconify-frame frame))
	     ('nil  (make-frame-invisible frame)))))))

(defun display-frame-until (frame &optional buffer condition)
  "Display FRAME topmost with optional BUFFER in its selected window until CONDITION or `display-until-delay' seconds.

FRAME may be an existing, even invisible frame, frame name or
nil.  If nil, the selected frame is used.  If FRAME is a string
and no live frame with that name is found, a new one with the
name and any `display-until-frame-parameters' is created.

BUFFER may be an existing buffer or buffer name.

CONDITION must be an unquoted boolean predicate form.

After display, FRAME's prior visibility status is restored, as is
the prior frame that had input focus.  FRAME's depth in the frame
stacking order is not restored."
  (let ((prior-frame (or (frame-focus) (selected-frame))))
    (display-frame-until-condition frame buffer condition)
    (select-frame-set-input-focus prior-frame)))

(defun display-window-until (win-or-buf &optional buffer condition)
  "Display WIN-OR-BUF's frame topmost with optional BUFFER in its selected window until CONDITION or `display-until-delay' seconds.

WIN-OR-BUF may be a window, existing buffer or buffer name, or nil.
If a buffer or buffer name, any window presently with that buffer
is used.  If nil or if no window is associated with the buffer, the
selected window is used.

The first matching item from this list is displayed in the chosen window:
BUFFER if it is non-nil; WIN-OR-BUF if it is a buffer or buffer name;
the window's current buffer.

CONDITION must be an unquoted boolean predicate form.

After display, WIN-OR-BUF frame's prior visibility status is
restored, as is the prior frame that had input focus.  WIN-OR-BUF
frame's depth in the frame stacking order is not restored."
  (unless win-or-buf
    (setq win-or-buf (selected-window)))
  (when (or (stringp win-or-buf) (bufferp win-or-buf))
    (setq win-or-buf (or (get-buffer-window win-or-buf t) win-or-buf))
    (when (and (stringp win-or-buf) (get-buffer win-or-buf))
      ;; Set to display the buffer given by win-or-buf.
      (unless buffer (setq buffer win-or-buf))
      ;; Use selected window since no other window to use was found.
      (setq win-or-buf (selected-window))))
  (unless (window-live-p win-or-buf)
    (error "(display-window-until): First argument must reference a live window, not `%s'"
	   win-or-buf))
  ;; Don't use with-selected-window here since it affects frame visibility.
  (let ((sel-window (selected-window)))
    (select-window win-or-buf)
    (display-frame-until-condition (window-frame win-or-buf) buffer condition)
    (select-window sel-window)
    (select-frame-set-input-focus (window-frame sel-window))))

;;; Sample Usage and Tests - Interactively evaluate these Lisp forms

;; The Lisp reader will ignore these samples when loading the library
(when nil

  ;; Display frames atop the window stack for 2 seconds
  (setq display-until-delay 2)

  ;; Create a new frame named 'My-Frame', make it display the *Messages*
  ;; buffer, temporarily display it, then hide it.
  (progn (when (display-until-get-frame-by-name "My-Frame")
	   (delete-frame (display-until-get-frame-by-name "My-Frame")))
	 (let ((display-until-frame-parameters '((visibility . nil))))
	   (display-frame-until "My-Frame" "*Messages*")))

  ;; Temporarily display My-Frame, then leave it displayed but move
  ;; prior topmost frame back to the top.
  (progn (set-frame-parameter (display-until-get-frame-by-name "My-Frame") 'visibility t)
	 (display-frame-until "My-Frame"))

  ;; Temporarily display the frame of a specific window (one currently
  ;; showing the *Messages* buffer) and make it display the *scratch* buffer.
  (display-window-until "*Messages*" "*scratch*")

  ;; Temporarily display an existing frame.
  (display-frame-until "My-Frame")

  ;; Temporarily display an existing window.
  (display-window-until "*scratch*")

  ;; Temporarily display a window currently showing "*scratch*" and
  ;; switch it to the buffer "*Messages*".
  (display-window-until "*scratch*" "*Messages*")

  ;; Likely display the buffer "*scratch*" in the selected window.
  (display-window-until "*scratch*")
  )

(provide 'display-until)
