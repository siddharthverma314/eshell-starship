;;; eshell-starship.el --- Starship prompt for eshell. -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Siddharth Verma.

;; Author: Siddharth Verma <siddharthverma314@gmail.com>
;; Keywords: eshell prompt starship
;; Homepage: https://github.com/siddharthverma314/eshell-starship

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The starship prompt (https://starship.rs) is a cross-platform shell
;; prompt written in rust. This package provides integration to use
;; this within eshell.

;; To use this package, install starship and set your default font in
;; Emacs to be a Nerd Font (https://www.nerdfonts.com). Then, run
;; `eshell-starship-setup' to enable the starship prompt within
;; eshell.

;;; Code:

(require 'ansi-color)
(require 'eshell)
(require 'em-term)
(require 'em-prompt)
(require 'map)

(defgroup eshell-starship nil
  "EShell starship package.")

(defcustom eshell-starship-command "starship"
  "Name or path to starship command"
  :type 'string
  :group 'eshell-starship)

(defcustom eshell-starship-term eshell-term-name
  "Set TERM to this value when calling starship.

Note that the emacs default TERM=dumb is not supported by starship."
  :type 'string
  :group 'eshell-starship)

(defcustom eshell-starship-config (expand-file-name "~/.config/starship.toml")
  "Starship config to use."
  :type 'file
  :group 'eshell-starship)

;; eshell command time tracking
(defvar-local eshell-starship--last-cmd-time nil
  "An alist containing start and end times of the last run eshell command.")

(defun eshell-starship--start-timer ()
  (setq-local eshell-starship--last-cmd-time
              (map-insert nil 'start (current-time))))

(defun eshell-starship--stop-timer ()
  (setf (map-elt eshell-starship--last-cmd-time 'stop) (current-time)))

(defun eshell-starship--elasped-millis ()
  "Calculate the difference between the start and end times stored in
`eshell-starship--last-cmd-time' in milliseconds."
  (let ((delta (time-subtract (map-elt eshell-starship--last-cmd-time 'stop)
                              (map-elt eshell-starship--last-cmd-time 'start))))
    (round (* 1000 (float-time delta)))))

;; starship prompt
(defvar eshell-starship--default-prompt-function nil
  "Set to the previous eshell prompt after initialization.")

(defun eshell-starship-prompt-string ()
  "Returns the starship prompt as a string.

Prompt is returned as an ansi escaped string. If
`eshell-starship-command' is not found, then returns the output of the
previously set eshell prompt function."
  (condition-case nil
      (ansi-color-apply
       ;; session key is derived from buffer-name which is unique
       (let ((eshell-starship-session-key (md5 (buffer-name))))
         (with-temp-buffer
           (with-environment-variables
               (("TERM" eshell-starship-term)
                ("STARSHIP_CONFIG" eshell-starship-config)
                ("STARSHIP_SESSION_KEY" eshell-starship-session-key)
                ("STARSHIP_SHELL" "eshell"))
             (call-process
              eshell-starship-command nil t nil
              "prompt"
              (format "--status=%d" eshell-last-command-status)
              (format "--terminal-width=%d" (window-width))
              (format "--cmd-duration=%d" (eshell-starship--elasped-millis))))
           (buffer-string))))
    ('file-missing
     (warn "Starship program %s not found" eshell-starship-command)
     (funcall eshell-starship--default-prompt-function))))

(defun eshell-starship-setup ()
  "Setup starship prompt for use within eshell."
  (interactive)
  ;; save previous prompt function
  (setq eshell-starship--default-prompt-function eshell-prompt-function)
  ;; setup starship prompt
  (setq eshell-prompt-function #'eshell-starship-prompt-string)
  ;; do not override starship higlighting
  (setq eshell-highlight-prompt nil)
  ;; setup timing functions
  (add-hook 'eshell-pre-command-hook #'eshell-starship--start-timer)
  (add-hook 'eshell-post-command-hook #'eshell-starship--stop-timer))

(provide 'eshell-starship)
