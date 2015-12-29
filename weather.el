;;; weather.el --- Displays your weather information in mode-line  -*- lexical-binding: t; -*-

;; Copyright (C) 2004-2015 Free Software Foundation, Inc.

;; Author: DarkSun <lujun9972@gmail.com>
;; URL: https://github.com/lujun9972/weather-mode
;; Package-Requires: ((emacs "24"))
;; Keywords: weather, mode-line
;; Created: 2015-12-28
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; customize the weather-location and then 
;;
;;   M-x weather-mode

;;; Code:

(require 'url)
(require 'json)

(defgroup weather nil
  "Weather minor mode"
  :group 'emacs)

(defcustom weather-location "东莞"
  "location"
  :type 'string
  :group 'weather)

(defcustom weather-update-interval 60
  "Seconds after which the weather information will be updated."
  :type 'integer
  :group 'weather)

(defvar weather-info ""
  "weather information")

(defvar weather-env (url-hexify-string "store://datatables.org/alltableswithkeys"))

(defun weather-get-query-url (location env)
  "generate url that used to fetch weather information"
  (let* ((yql_query (url-hexify-string (format "select * from weather.forecast where woeid in (select woeid from geo.places(1) where text='%s')" location)))
         (url (format 
               "https://query.yahooapis.com/v1/public/yql?q=%s&format=json&env=%s" yql_query env)))
    url))

(defun weather--extract-from-json-object (json-object extract-place-list)
  "extract data from JSON-OBJECT which responsed by yahoo weather"
  (let* ((place (car extract-place-list))
         (extract-place-list (cdr extract-place-list))
         (json-object (cdr (assoc place json-object))))
    (if extract-place-list
        (weather--extract-from-json-object json-object extract-place-list)
      json-object)))

(defun weather-update-info-cb (status &rest cbargs)
  (let (content)
    (goto-char (point-min))
    (when (search-forward-regexp "^$" nil t)
      (setq content (buffer-substring-no-properties (+ (point) 1) (point-max))))
    (kill-buffer)
    (let* ((json-object (json-read-from-string content))
           (temperature (weather--extract-from-json-object json-object '(query results channel item condition temp)))
           (text (weather--extract-from-json-object json-object '(query results channel item condition text))))
      (setq weather-info (format "%s %sF" text temperature)))))

(defun weather-update-info ()
  "update weather information"
  (interactive)
  (let ((url (weather-get-query-url weather-location weather-env)))
    (url-retrieve url 'weather-update-info-cb nil t)))


;;; Glboal Minor-mode

(defcustom weather-mode-line
  '(:eval
    (format "[%s]" weather-info))
  "Mode line lighter for weather-mode."
  :type 'sexp
  :group 'weather)

(put 'weather-mode-line 'risky-local-variable t)

(defvar weather-update-info-timer nil)

;;;###autoload
(define-minor-mode weather-mode
  "Toggle weather information display in mode line (weather information mode).
With a prefix argument ARG, enable weather mode if ARG is
positive, and disable it otherwise.  If called from Lisp, enable
the mode if ARG is omitted or nil."
  :global t :group 'weather
  (unless global-mode-string
    (setq global-mode-string '("")))
  (when (timerp weather-update-info-timer)
    (cancel-timer weather-update-info-timer))
  (if (not weather-mode)
      (setq global-mode-string
            (delq 'weather-mode-line global-mode-string))
    (setq weather-update-info-timer (run-at-time nil weather-update-interval #'weather-update-info))
    (add-to-list 'global-mode-string 'weather-mode-line t)
    (weather-update-info)))

(provide 'weather)
;;; weather.el ends here