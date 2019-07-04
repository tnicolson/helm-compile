;;; helm-compile.el --- Search compilation history with Helm
;; Copyright 2017 Tim Nicolson
;;
;; Author: Tim Nicolson <tim@nicolson.info>
;; Keywords: helm compile
;; URL: https://github.com/tnicolson/helm-compile
;; Created: 28th October 2017
;; Version: 0.1.1

;;; Commentary:
;;
;; Search your compilation history with Helm. Select or edit command, then run.
;;

(require 'f)
(require 's)
(require 'dash)
(require 'helm)
(require 'compile)

(defvar helm-compile-pre-compilation-hook nil)
(defvar helm-compile-compilation-hook nil)
(defvar helm-compile-build-machine nil)
(defvar helm-compile-project-root nil)
(defvar helm-compile-locate-dominating-file ".git"
    "Locate dominating file before running compilation so that it's executed in
   correct directory (e.g. project root)")

(defun helm-compile--get-project-directory ()
  (if helm-compile-project-root
      helm-compile-project-root
    (locate-dominating-file (helm-default-directory) helm-compile-locate-dominating-file)))

(defun helm-compile--get-build-directory ()
  (let ((dir (helm-compile--get-project-directory)))
    (if helm-compile-build-machine
        (format "/ssh:%s:%s" helm-compile-build-machine dir)
      dir)))

(defun helm-compile--do-compile (project command &optional comint)
  (with-temp-buffer
    (progn
      (push command compile-history)
      (compile command comint))))

(defun helm-compile--compile (command &optional comint)
  (let ((dir (helm-compile--get-build-directory)))
    (run-hooks 'helm-compile-pre-compilation-hook)
    (let* ((default-directory dir)
           (project (f-base default-directory)))
      (helm-compile--do-compile project command comint)
      (run-hooks 'helm-compile-compilation-hook))))

(defun helm-compile--edit (command)
  (interactive)
  (read-from-minibuffer "Compile: " command))

(setq helm-compile-history
  (helm-build-sync-source "Compile History"
    :candidates (lambda () (delete-dups compile-history))
    :action '(("Compile" . (lambda (candidate) (helm-compile--compile candidate)))
              ("Edit" . (lambda (candidate) (helm-compile--compile (helm-compile--edit candidate))))
              ("Remove from history" . (lambda (ignore)
                                         (mapc (lambda (candidate) (delete candidate compile-history))
                                               (helm-marked-candidates)))))))

(defun helm-compile ()
  "Preconfigured `helm' for compile."
  (interactive)
  (when (and (buffer-file-name) (buffer-modified-p))
    (save-buffer))
  (helm :sources '(helm-compile-history)
        :buffer "*helm compile*"))

(add-to-list 'savehist-additional-variables 'compile-history)

(provide 'helm-compile)

