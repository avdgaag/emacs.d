;; -*- coding: utf-8 -*-

;;----------------------------------------------------------------------------
;; Which functionality to enable (use t or nil for true and false)
;;----------------------------------------------------------------------------
(setq *vi-emulation-support-enabled* nil) ; "viper-mode"
(setq *haskell-support-enabled* t)
(setq *ocaml-support-enabled* t)
(setq *common-lisp-support-enabled* t)
(setq *clojure-support-enabled* t)
(setq *scheme-support-enabled* t)
(setq *macbook-pro-support-enabled* t)
(setq *erlang-support-enabled* t)
(setq *rails-support-enabled* t)
(setq *spell-check-support-enabled* nil)
(setq *byte-code-cache-enabled* nil)
(setq *twitter-support-enabled* nil)
(setq *is-a-mac* (eq system-type 'darwin))
(setq *is-carbon-emacs* (and *is-a-mac* (eq window-system 'mac)))
(setq *is-cocoa-emacs* (and *is-a-mac* (eq window-system 'ns)))


;;----------------------------------------------------------------------------
;; Make elisp more civilised
;;----------------------------------------------------------------------------
(require 'cl)


;;----------------------------------------------------------------------------
;; Set load path
;;----------------------------------------------------------------------------
(if (fboundp 'normal-top-level-add-subdirs-to-load-path)
    (let* ((my-lisp-dir "~/.emacs.d/site-lisp/")
           (default-directory my-lisp-dir))
      (progn
        (setq load-path (cons my-lisp-dir load-path))
        (normal-top-level-add-subdirs-to-load-path))))
(setq load-path (cons (expand-file-name "~/.emacs.d") load-path))


;;----------------------------------------------------------------------------
;; Automatically byte-compile .el files
;;----------------------------------------------------------------------------
(when *byte-code-cache-enabled*
  (require 'init-byte-code-cache))


;;----------------------------------------------------------------------------
;; Use elisp package manager (http://tromey.com/elpa/)
;;----------------------------------------------------------------------------
(require 'package)
(package-initialize)

(add-to-list 'package-archives
             '("technomancy" . "http://repo.technomancy.us/emacs/") t)


;;----------------------------------------------------------------------------
;; Handier way to add modes to auto-mode-alist
;;----------------------------------------------------------------------------
(defun add-auto-mode (mode &rest patterns)
  (dolist (pattern patterns)
    (add-to-list 'auto-mode-alist (cons pattern mode))))


;;----------------------------------------------------------------------------
;; Find the directory containing a given library
;;----------------------------------------------------------------------------
(require 'find-func)
(defun directory-of-library (library-name)
  (file-name-as-directory (file-name-directory (find-library-name library-name))))


;;----------------------------------------------------------------------------
;; Easy way to check that we're operating on a specific file type
;;----------------------------------------------------------------------------
(defun filename-has-extension-p (extensions)
  (and buffer-file-name
       (string-match (concat "\\." (regexp-opt extensions t) "\\($\\|\\.\\)") buffer-file-name)))


;;----------------------------------------------------------------------------
;; Locate executables
;;----------------------------------------------------------------------------
(defun find-executable (name)
  "Return the full path of an executable file name `name'
in `exec-path', or nil if no such command exists"
  (loop for dir in exec-path
        for full-path = (expand-file-name (concat dir "/" name))
        when (file-executable-p full-path)
        return full-path))


;;----------------------------------------------------------------------------
;; Augment search path for external programs (for OSX)
;;----------------------------------------------------------------------------
(defun set-exec-path-from-shell-PATH ()
  (let ((path-from-shell (shell-command-to-string "$SHELL -i -c 'echo $PATH'")))
    (setenv "PATH" path-from-shell)
    (setq exec-path (split-string path-from-shell path-separator))))

(when *is-a-mac*
  (eval-after-load "woman"
    '(setq woman-manpath (append (list "/opt/local/man") woman-manpath)))

  ;; When started from Emacs.app or similar, ensure $PATH
  ;; is the same the user would see in Terminal.app
  (if window-system (set-exec-path-from-shell-PATH)))


;;----------------------------------------------------------------------------
;; Add hooks to allow conditional setup of window-system and console frames
;;----------------------------------------------------------------------------
(defvar after-make-console-frame-hooks '()
  "Hooks to run after creating a new TTY frame")
(defvar after-make-window-system-frame-hooks '()
  "Hooks to run after creating a new window-system frame")

(defun run-after-make-frame-hooks (frame)
  "Selectively run either `after-make-console-frame-hooks' or
`after-make-window-system-frame-hooks'"
  (select-frame frame)
  (run-hooks (if window-system
                 'after-make-window-system-frame-hooks
               'after-make-console-frame-hooks)))

(add-hook 'after-make-frame-functions 'run-after-make-frame-hooks)


;;----------------------------------------------------------------------------
;; Console-specific set-up
;;----------------------------------------------------------------------------
(defun fix-up-xterm-control-arrows ()
  (define-key function-key-map "\e[1;5A" [C-up])
  (define-key function-key-map "\e[1;5B" [C-down])
  (define-key function-key-map "\e[1;5C" [C-right])
  (define-key function-key-map "\e[1;5D" [C-left])
  (define-key function-key-map "\e[5A"   [C-up])
  (define-key function-key-map "\e[5B"   [C-down])
  (define-key function-key-map "\e[5C"   [C-right])
  (define-key function-key-map "\e[5D"   [C-left]))

(add-hook 'after-make-console-frame-hooks
          (lambda ()
            (fix-up-xterm-control-arrows)
            (xterm-mouse-mode 1) ; Mouse in a terminal (Use shift to paste with middle button)
            (mwheel-install)))

(add-hook 'after-make-frame-functions
          (lambda (frame)
            (let ((prev-frame (selected-frame)))
              (select-frame frame)
              (prog1
                  (unless window-system
                    (set-frame-parameter frame 'menu-bar-lines 0))
                (select-frame prev-frame)))))


;;----------------------------------------------------------------------------
;; Include buffer name and file path in title bar
;;----------------------------------------------------------------------------
(defvar *user*    (user-login-name) "user login name")
(defvar *hostname*
  (let ((n (system-name))) (substring n 0 (string-match "\\." n))) "unqualified host name")

(defun network-location ()
  "Report the network location of this computer; only implemented for Macs"
  (when *is-a-mac*
    (let ((scselect (shell-command-to-string "/usr/sbin/scselect")))
      (if (string-match "^ \\* .*(\\(.*\\))$" scselect)
          (match-string 1 scselect)))))

(defun concise-network-location ()
  (let ((l (network-location)))
    (if (and l (not (string-equal "Automatic" l)))
        (concat "[" l "]")
      "")))

(defun concise-buffer-file-name ()
  (when (buffer-file-name)
    (replace-regexp-in-string (regexp-quote (getenv "HOME")) "~" (buffer-file-name))))
(setq frame-title-format '("%b - " *user* "@" *hostname*
                           (:eval (concise-network-location)) " - "
                           (:eval (concise-buffer-file-name))))


;;----------------------------------------------------------------------------
;; Make yes-or-no questions answerable with 'y' or 'n'
;;----------------------------------------------------------------------------
(fset 'yes-or-no-p 'y-or-n-p)


;;----------------------------------------------------------------------------
;; Stop C-z from minimizing windows under OS X
;;----------------------------------------------------------------------------
(global-set-key (kbd "C-z")
                (lambda ()
                  (interactive)
                  (unless (and *is-a-mac* window-system)
                    (suspend-frame))))


;;----------------------------------------------------------------------------
;; Overwrite text when the selection is active
;;----------------------------------------------------------------------------
(delete-selection-mode 1)


;;----------------------------------------------------------------------------
;; Handy key bindings
;;----------------------------------------------------------------------------
;; To be able to M-x without meta
(global-set-key (kbd "C-x C-m") 'execute-extended-command)

(global-set-key (kbd "C-c j") 'join-line)
(global-set-key (kbd "C-c J") (lambda () (interactive) (join-line 1)))
(global-set-key (kbd "M-T") 'transpose-lines)

 (defun duplicate-line ()
    (interactive)
    (save-excursion
      (let ((line-text (buffer-substring-no-properties
                        (line-beginning-position)
                        (line-end-position))))
        (move-end-of-line 1)
        (newline)
        (insert line-text))))

(global-set-key (kbd "C-c p") 'duplicate-line)

;; Train myself to use M-f and M-b instead
(global-unset-key [M-left])
(global-unset-key [M-right])

;; paredit-kill-sexps-on-whole-line


;;----------------------------------------------------------------------------
;; Shift lines up and down
;;----------------------------------------------------------------------------
(defun move-text-internal (arg)
  (cond
   ((and mark-active transient-mark-mode)
    (if (> (point) (mark))
        (exchange-point-and-mark))
    (let ((column (current-column))
          (text (delete-and-extract-region (point) (mark))))
      (forward-line arg)
      (move-to-column column t)
      (set-mark (point))
      (insert text)
      (exchange-point-and-mark)
      (setq deactivate-mark nil)))
   (t
    (let ((column (current-column)))
      (beginning-of-line)
      (when (or (> arg 0) (not (bobp)))
        (forward-line)
        (when (or (< arg 0) (not (eobp)))
          (transpose-lines arg))
        (forward-line -1))
      (move-to-column column t)))))

(defun move-text-down (arg)
  "Move region (transient-mark-mode active) or current line
  arg lines down."
  (interactive "*p")
  (move-text-internal arg))

(defun move-text-up (arg)
  "Move region (transient-mark-mode active) or current line
  arg lines up."
  (interactive "*p")
  (move-text-internal (- arg)))


(global-set-key [M-S-up] 'move-text-up)
(global-set-key [M-S-down] 'move-text-down)



;;----------------------------------------------------------------------------
;; Cut/copy the current line if no region is active
;;----------------------------------------------------------------------------
(defadvice kill-ring-save (before slick-copy activate compile) "When called
  interactively with no active region, copy a single line instead."
  (interactive (if mark-active (list (region-beginning) (region-end))
                 (message "Copied line")
                 (list (line-beginning-position)
                       (line-beginning-position 2)))))

(defadvice kill-region (before slick-cut activate compile)
  "When called interactively with no active region, kill a single line instead."
  (interactive
    (if mark-active (list (region-beginning) (region-end))
      (message "Killed line")
      (list (line-beginning-position)
        (line-beginning-position 2)))))


;;----------------------------------------------------------------------------
;; OS X usability tweaks
;;----------------------------------------------------------------------------
(when *is-a-mac*
  (setq mac-command-modifier 'meta)
  (setq mac-option-modifier 'none)
  (setq default-input-method "MacOSX")
  ;; Make mouse wheel / trackpad scrolling less jerky
  (setq mouse-wheel-scroll-amount '(0.001))
  (when *is-cocoa-emacs*
    ;; Woohoo!!
    (global-set-key (kbd "M-`") 'ns-next-frame)
    (global-set-key (kbd "M-h") 'ns-do-hide-emacs)
    (global-set-key (kbd "M-ˍ") 'ns-do-hide-others) ;; what describe-key reports
    (global-set-key (kbd "M-c") 'ns-copy-including-secondary)
    (global-set-key (kbd "M-v") 'ns-paste-secondary))
  ;; Use Apple-w to close current buffer on OS-X (is normally bound to kill-ring-save)
  (eval-after-load "viper"
    '(global-set-key [(meta w)] 'kill-this-buffer)))


;;----------------------------------------------------------------------------
;; Suppress GUI features
;;----------------------------------------------------------------------------
(setq use-file-dialog nil)
(setq use-dialog-box nil)
(setq inhibit-startup-screen t)


;;----------------------------------------------------------------------------
;; Network proxy configuration
;;----------------------------------------------------------------------------
(require 'init-proxies)


;;----------------------------------------------------------------------------
;; Enhanced dired
;;----------------------------------------------------------------------------
(require 'dired+)
(setq dired-recursive-deletes 'top)
(define-key dired-mode-map [mouse-2] 'dired-find-file)


;;----------------------------------------------------------------------------
;; Show and edit all lines matching a regex
;;----------------------------------------------------------------------------
(require 'all)


;;----------------------------------------------------------------------------
;; VI emulation and related key mappings
;;----------------------------------------------------------------------------
(eval-after-load "viper"
  '(progn
     ;; C-z is usually 'iconify-or-deiconify-frame, but viper uses it to toggle
     ;; vi/emacs input modes, causing confusion in non-viper buffers

     (global-unset-key "\C-z")
     (setq viper-mode t)
     (setq viper-custom-file-name (convert-standard-filename "~/.emacs.d/.viper"))
     (require 'viper)
     (define-key viper-insert-global-user-map [kp-delete] 'viper-delete-char)
     (define-key viper-insert-global-user-map (kbd "C-n") 'dabbrev-expand)
     (define-key viper-insert-global-user-map (kbd "C-p") 'dabbrev-expand)

     ;; Stop C-u from clobbering prefix-arg -- I always use C-b/C-f to scroll

     (define-key viper-vi-basic-map "\C-u" nil)

     ;; Vim-style searching of the symbol at point, made easy by highlight-symbol

     (autoload 'highlight-symbol-next "highlight-symbol" "Highlight symbol at point")
     (autoload 'highlight-symbol-prev "highlight-symbol" "Highlight symbol at point")
     (setq highlight-symbol-on-navigation-p t)
     (define-key viper-vi-global-user-map "*" 'highlight-symbol-next)
     (define-key viper-vi-global-user-map "#" 'highlight-symbol-prev)))


;; Work around a problem in Cocoa emacs, wherein setting the cursor coloring
;; is incredibly slow; viper sets the cursor very frequently in insert mode
(when *is-cocoa-emacs*
  (eval-after-load "viper"
    '(defun viper-change-cursor-color (new-color &optional frame))))


;;----------------------------------------------------------------------------
;; Show a marker in the left fringe for lines not in the buffer
;;----------------------------------------------------------------------------
(setq default-indicate-empty-lines t)


;;----------------------------------------------------------------------------
;; Don't disable case-change functions
;;----------------------------------------------------------------------------
(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)


;;----------------------------------------------------------------------------
;; Navigate window layouts with "C-c <left>" and "C-c <right>"
;;----------------------------------------------------------------------------
(winner-mode 1)


;;----------------------------------------------------------------------------
;; Navigate windows "C-<arrow>"
;;----------------------------------------------------------------------------
(windmove-default-keybindings 'control)


;;----------------------------------------------------------------------------
;; isearch config
;;----------------------------------------------------------------------------
;; Use regex searching by default
(global-set-key "\C-s" 'isearch-forward-regexp)
(global-set-key "\C-r" 'isearch-backward-regexp)
(global-set-key "\C-\M-s" 'isearch-forward)
(global-set-key "\C-\M-r" 'isearch-backward)

(defun call-with-current-isearch-string-as-regex (f)
  (let ((case-fold-search isearch-case-fold-search))
    (funcall f (if isearch-regexp isearch-string (regexp-quote isearch-string)))))

;; Activate occur easily inside isearch
(define-key isearch-mode-map (kbd "C-o")
  (lambda ()
    (interactive)
    (call-with-current-isearch-string-as-regex 'occur)))

;; or fire up "all"
(define-key isearch-mode-map (kbd "C-l")
  (lambda ()
    (interactive)
    (call-with-current-isearch-string-as-regex 'all)))

;; Search back/forth for the symbol at point
;; See http://www.emacswiki.org/emacs/SearchAtPoint
(defun isearch-yank-symbol ()
  "*Put symbol at current point into search string."
  (interactive)
  (let ((sym (symbol-at-point)))
    (if sym
        (progn
          (setq isearch-regexp t
                isearch-string (concat "\\_<" (regexp-quote (symbol-name sym)) "\\_>")
                isearch-message (mapconcat 'isearch-text-char-description isearch-string "")
                isearch-yank-flag t))
      (ding)))
  (isearch-search-and-update))

(define-key isearch-mode-map "\C-\M-w" 'isearch-yank-symbol)


;;----------------------------------------------------------------------------
;; Edit multiple matching strings in place simultaneously
;;----------------------------------------------------------------------------
(autoload 'iedit-mode "iedit" "Edit current search matches")
(global-set-key (kbd "C-;") 'iedit-mode)
(eval-after-load "iedit"
  '(define-key iedit-mode-map (kbd "C-g") 'iedit-mode))


;;----------------------------------------------------------------------------
;; Easily count words (http://emacs-fu.blogspot.com/2009/01/counting-words.html)
;;----------------------------------------------------------------------------
(defun count-words (&optional begin end)
  "count words between BEGIN and END (region); if no region defined, count words in buffer"
  (interactive "r")
  (let ((b (if mark-active begin (point-min)))
      (e (if mark-active end (point-max))))
    (message "Word count: %s" (how-many "\\w+" b e))))


;;----------------------------------------------------------------------------
;; Modeline tweaks
;;----------------------------------------------------------------------------
(size-indication-mode)
(column-number-mode 1)


;;----------------------------------------------------------------------------
;; Highlight parentheses
;;----------------------------------------------------------------------------
(setq show-paren-style 'mixed)
(show-paren-mode 1)


;;----------------------------------------------------------------------------
;; Scroll the window smoothly with the up/down arrows
;;----------------------------------------------------------------------------
(require 'smooth-scrolling)
(setq scroll-preserve-screen-position t)


;;----------------------------------------------------------------------------
;; Nicer naming of buffers for files with identical names
;;----------------------------------------------------------------------------
(require 'uniquify)

(setq uniquify-buffer-name-style 'reverse)
(setq uniquify-separator " • ")
(setq uniquify-after-kill-buffer-p t)
(setq uniquify-ignore-buffers-re "^\\*")


;;----------------------------------------------------------------------------
;; Use ibuffer instead of the built in buffer list
;;----------------------------------------------------------------------------
(global-set-key (kbd "C-x C-b") 'ibuffer)


;;----------------------------------------------------------------------------
;; Highlight URLs in comments/strings
;;----------------------------------------------------------------------------
(add-hook 'find-file-hooks 'goto-address-prog-mode)


;;----------------------------------------------------------------------------
;; Basic flymake configuration
;;----------------------------------------------------------------------------
(require 'init-flymake)


;;----------------------------------------------------------------------------
;; Luke Gorrie's "lively.el"
;;----------------------------------------------------------------------------
(autoload 'lively "lively" "Interactively updating text" t)


;;----------------------------------------------------------------------------
;; Twitter
;;----------------------------------------------------------------------------
(when *twitter-support-enabled*
  (require 'init-twitter))


;;----------------------------------------------------------------------------
;; Erlang
;;----------------------------------------------------------------------------
(require 'init-erlang)


;;----------------------------------------------------------------------------
;; Javascript
;;----------------------------------------------------------------------------
(require 'init-javascript)

;;----------------------------------------------------------------------------
;; Extensions -> Modes
;;----------------------------------------------------------------------------
(add-auto-mode 'html-mode "\\.(jsp|tmpl)$")
(add-auto-mode 'tcl-mode "Portfile$")


;;----------------------------------------------------------------------------
;; Crontab mode
;;----------------------------------------------------------------------------
(autoload 'crontab-mode "crontab-mode" "Mode for editing crontab files" t)
(add-auto-mode 'crontab-mode "\\.?cron\\(tab\\)?\\'")


;;----------------------------------------------------------------------------
;; Textile-mode
;;----------------------------------------------------------------------------
(autoload 'textile-mode "textile-mode" "Mode for editing Textile documents" t)


;;----------------------------------------------------------------------------
;; Markdown-mode
;;----------------------------------------------------------------------------
(autoload 'markdown-mode "markdown-mode" "Mode for editing Markdown documents" t)


;;----------------------------------------------------------------------------
;; Regex-tool
;;----------------------------------------------------------------------------
(autoload 'regex-tool "regex-tool" "Mode for exploring regular expressions" t)
(setq regex-tool-backend 'perl)


;;----------------------------------------------------------------------------
;; Subversion
;;----------------------------------------------------------------------------
(autoload 'svn-status "psvn" "Mode for inspecting state of an svn repo")
(autoload 'svn-examine "psvn" "Mode for inspecting state of an svn repo")


;;----------------------------------------------------------------------------
;; Darcs
;;----------------------------------------------------------------------------
(require 'init-darcs)


;;----------------------------------------------------------------------------
;; Git
;;----------------------------------------------------------------------------
(require 'init-git)


;;----------------------------------------------------------------------------
;; Multiple major modes
;;----------------------------------------------------------------------------
(require 'mmm-auto)
(setq mmm-global-mode 'buffers-with-submode-classes)
(setq mmm-submode-decoration-level 2)


;;----------------------------------------------------------------------------
;; File and buffer navigation
;;----------------------------------------------------------------------------
(recentf-mode 1)
(setq recentf-max-saved-items 100)
(require 'init-ido)
(require 'init-anything)


;;----------------------------------------------------------------------------
;; Rectangle selections
;;----------------------------------------------------------------------------
(setq cua-enable-cua-keys nil) ;; only for rectangles, with C-RET
(cua-mode t)


;;----------------------------------------------------------------------------
;; Hippie-Expand
;;----------------------------------------------------------------------------
(global-set-key (kbd "M-/") 'hippie-expand)

(setq hippie-expand-try-functions-list
      '(try-complete-file-name-partially
        try-complete-file-name
        try-expand-dabbrev
        try-expand-dabbrev-all-buffers
        try-expand-dabbrev-from-kill))


;;----------------------------------------------------------------------------
;; Autocomplete
;;----------------------------------------------------------------------------
(require 'auto-complete)
(require 'auto-complete-config)
(global-auto-complete-mode t)
(setq ac-auto-start nil)
(setq ac-dwim t)
(define-key ac-complete-mode-map (kbd "C-n") 'ac-next)
(define-key ac-complete-mode-map (kbd "C-p") 'ac-previous)

(defun indent-or-expand-with-ac (&optional arg)
  "Either indent according to mode, or expand the word preceding point."
  (interactive "*P")
  (if (and
       (not mark-active)
       (not (minibufferp))
       (memq 'auto-complete-mode minor-mode-list)
       (looking-at "\\_>"))
      (ac-start)
    (indent-for-tab-command arg)))

(global-set-key (kbd "TAB") 'indent-or-expand-with-ac)

(set-default 'ac-sources
             (if (> emacs-major-version 22)
                 (progn
                   (require 'ac-dabbrev)
                   '(ac-source-dabbrev ac-source-words-in-buffer))
               ;; dabbrev is very slow in emacs 22
               '(ac-source-words-in-buffer)))

(dolist (mode '(magit-log-edit-mode log-edit-mode org-mode text-mode haml-mode
                sass-mode yaml-mode csv-mode espresso-mode haskell-mode
                html-mode nxml-mode sh-mode smarty-mode clojure-mode
                lisp-mode textile-mode markdown-mode tuareg-mode))
  (add-to-list 'ac-modes mode))


(eval-after-load "viper"
  '(progn
     (define-key ac-complete-mode-map (kbd "C-n") 'dabbrev-expand)
     (define-key ac-complete-mode-map (kbd "C-p") 'dabbrev-expand)
     (define-key ac-complete-mode-map viper-ESC-key 'viper-intercept-ESC-key)))

;; Exclude very large buffers from dabbrev
(defun smp-dabbrev-friend-buffer (other-buffer)
  (< (buffer-size other-buffer) (* 1 1024 1024)))

(setq dabbrev-friend-buffer-function 'smp-dabbrev-friend-buffer)


;;----------------------------------------------------------------------------
;; When splitting window, show (other-buffer) in the new window
;;----------------------------------------------------------------------------
(require 'init-window-split)


;;----------------------------------------------------------------------------
;; Desktop saving
;;----------------------------------------------------------------------------
;; save a list of open files in ~/.emacs.d/.emacs.desktop
;; save the desktop file automatically if it already exists
(setq desktop-path '("~/.emacs.d"))
(setq desktop-save 'if-exists)
(desktop-save-mode 1)


(autoload 'save-current-configuration "revive" "Save status" t)
(autoload 'resume "revive" "Resume Emacs" t)
(autoload 'wipe "revive" "Wipe Emacs" t)
(define-key ctl-x-map "S" 'save-current-configuration)
(define-key ctl-x-map "F" 'resume)
(define-key ctl-x-map "K" 'wipe)


;;----------------------------------------------------------------------------
;; Restore histories and registers after saving
;;----------------------------------------------------------------------------
(require 'session)
(setq session-save-file (expand-file-name "~/.emacs.d/.session"))
(add-hook 'after-init-hook 'session-initialize)

;; save a bunch of variables to the desktop file
;; for lists specify the len of the maximal saved data also
(setq desktop-globals-to-save
      (append '((extended-command-history . 30)
                (file-name-history        . 100)
                (ido-last-directory-list  . 100)
                (ido-work-directory-list  . 100)
                (ido-work-file-list       . 100)
                (grep-history             . 30)
                (compile-history          . 30)
                (minibuffer-history       . 50)
                (query-replace-history    . 60)
                (read-expression-history  . 60)
                (regexp-history           . 60)
                (regexp-search-ring       . 20)
                (search-ring              . 20)
                (shell-command-history    . 50)
                tags-file-name
                register-alist)))


;;----------------------------------------------------------------------------
;; Window size and features
;;----------------------------------------------------------------------------
(tool-bar-mode -1)
(scroll-bar-mode -1)
(set-fringe-mode 1)

(require 'init-maxframe)

(defun adjust-opacity (frame incr)
  (let* ((oldalpha (or (frame-parameter frame 'alpha) 100))
         (newalpha (+ incr oldalpha)))
    (when (and (<= frame-alpha-lower-limit newalpha) (>= 100 newalpha))
      (modify-frame-parameters frame (list (cons 'alpha newalpha))))))

(when (fboundp 'ns-toggle-fullscreen)
  ;; Command-Option-f to toggle fullscreen mode
  (global-set-key (kbd "M-ƒ") 'ns-toggle-fullscreen))

(global-set-key (kbd "C-8") '(lambda () (interactive) (adjust-opacity nil -5)))
(global-set-key (kbd "C-9") '(lambda () (interactive) (adjust-opacity nil 5)))
(global-set-key (kbd "C-0") '(lambda () (interactive) (modify-frame-parameters nil `((alpha . 100)))))


;;----------------------------------------------------------------------------
;; Fonts
;;----------------------------------------------------------------------------
(require 'init-fonts)


;;----------------------------------------------------------------------------
;; Color themes
;;----------------------------------------------------------------------------
(require 'init-themes)


;;----------------------------------------------------------------------------
;; Delete the current file
;;----------------------------------------------------------------------------
(defun delete-this-file ()
  (interactive)
  (or (buffer-file-name) (error "no file is currently being edited"))
  (when (yes-or-no-p "Really delete this file?")
    (delete-file (buffer-file-name))
    (kill-this-buffer)))


;;----------------------------------------------------------------------------
;; Compilation
;;----------------------------------------------------------------------------
(require 'todochiku) ;; growl notifications when compilation finishes
(add-hook 'compilation-mode-hook (lambda () (local-set-key [f6] 'recompile)))


;;----------------------------------------------------------------------------
;; Browse current HTML file
;;----------------------------------------------------------------------------
(defun browse-current-file ()
  (interactive)
  (browse-url (concat "file://" (buffer-file-name))))


;;----------------------------------------------------------------------------
;; Gnuplot
;;----------------------------------------------------------------------------
(autoload 'gnuplot-mode "gnuplot" "gnuplot major mode" t)
(autoload 'gnuplot-make-buffer "gnuplot" "open a buffer in gnuplot-mode" t)


;;----------------------------------------------------------------------------
;; Org-mode
;;----------------------------------------------------------------------------
(require 'init-org)


;;----------------------------------------------------------------------------
;; NXML
;;----------------------------------------------------------------------------
(require 'init-nxml)


;;----------------------------------------------------------------------------
;; Haml & Sass
;;----------------------------------------------------------------------------
(require 'init-haml)


;;----------------------------------------------------------------------------
;; Python
;;----------------------------------------------------------------------------
(require 'init-python-mode)


;;----------------------------------------------------------------------------
;; Ruby & Rails
;;----------------------------------------------------------------------------
(require 'init-ruby-mode)
(when *rails-support-enabled*
  (require 'init-rails))


;;----------------------------------------------------------------------------
; Automatically set execute perms on files if first line begins with '#!'
;;----------------------------------------------------------------------------
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)


;;----------------------------------------------------------------------------
;; htmlize
;;----------------------------------------------------------------------------
(dolist (sym
         (list 'htmlize-file 'htmlize-region 'htmlize-buffer
               'htmlize-many-files 'htmlize-many-files-dired))
  (autoload sym "htmlize"))


;;----------------------------------------------------------------------------
;; CSS mode
;;----------------------------------------------------------------------------
(require 'init-css)

;;----------------------------------------------------------------------------
;; YAML mode
;;----------------------------------------------------------------------------
(autoload 'yaml-mode "yaml-mode" "Mode for editing YAML files" t)
(add-auto-mode 'yaml-mode "\\.ya?ml$")


;;----------------------------------------------------------------------------
;; CSV mode and csv-nav mode
;;----------------------------------------------------------------------------
(autoload 'csv-mode "csv-mode" "Major mode for editing comma-separated value files." t)
(add-auto-mode 'csv-mode "\\.[Cc][Ss][Vv]\\'")
(autoload 'csv-nav-mode "csv-nav-mode" "Major mode for navigating comma-separated value files." t)


;;----------------------------------------------------------------------------
;; Shell mode
;;----------------------------------------------------------------------------
(autoload 'flymake-shell-load "flymake-shell" "On-the-fly syntax checking of shell scripts" t)
(add-hook 'sh-mode-hook 'flymake-shell-load)


;;----------------------------------------------------------------------------
;; PHP
;;----------------------------------------------------------------------------
(require 'init-php)


;;----------------------------------------------------------------------------
;; Lisp / Scheme / Slime
;;----------------------------------------------------------------------------
(require 'init-lisp)
(require 'init-slime)

(when *clojure-support-enabled*
  (require 'init-clojure))
(when *common-lisp-support-enabled*
  (require 'init-common-lisp))
(when *scheme-support-enabled*
  ; See http://bc.tech.coop/scheme/scheme-emacs.htm
  (require 'quack))

;;----------------------------------------------------------------------------
;; Haskell
;;----------------------------------------------------------------------------
(when *haskell-support-enabled*
  (require 'init-haskell))


;;----------------------------------------------------------------------------
;; OCaml
;;----------------------------------------------------------------------------
(when *ocaml-support-enabled*
  (setq auto-mode-alist (cons '("\\.ml\\w?" . tuareg-mode) auto-mode-alist))
  (autoload 'tuareg-mode "tuareg" "Major mode for editing Caml code" t)
  (autoload 'camldebug "camldebug" "Run the Caml debugger" t))


;;----------------------------------------------------------------------------
;; Add spell-checking in comments for all programming language modes
;;----------------------------------------------------------------------------
(when *spell-check-support-enabled*
  (when (find-executable "aspell")
    (setq ispell-program-name "aspell"
          ispell-extra-args '("--sug-mode=ultra")))
  (require 'init-flyspell))


;;----------------------------------------------------------------------------
;; Log typed commands into a buffer for demo purposes
;;----------------------------------------------------------------------------
(autoload 'mwe:log-keyboard-commands "mwe-log-commands"
  "Log commands executed in the current buffer" t)


;;----------------------------------------------------------------------------
;; Conversion of line endings
;;----------------------------------------------------------------------------
;; Can also use "C-x ENTER f dos" / "C-x ENTER f unix" (set-buffer-file-coding-system)
(require 'eol-conversion)


;;----------------------------------------------------------------------------
;; Allow access from emacsclient
;;----------------------------------------------------------------------------
(server-start)


;;----------------------------------------------------------------------------
;; Variables configured via the interactive 'customize' interface
;;----------------------------------------------------------------------------
(setq custom-file "~/.emacs.d/custom.el")
(load custom-file)


;;----------------------------------------------------------------------------
;; Locales (setting them earlier in this file doesn't work in X)
;;----------------------------------------------------------------------------
(when (or window-system (string-match "UTF-8" (shell-command-to-string "locale")))
  (setq utf-translate-cjk-mode nil) ; disable CJK coding/encoding (Chinese/Japanese/Korean characters)
  (set-language-environment 'utf-8)
  (when *is-carbon-emacs*
    (set-keyboard-coding-system 'utf-8-mac))
  (setq locale-coding-system 'utf-8)
  (set-default-coding-systems 'utf-8)
  (set-terminal-coding-system 'utf-8)
  (set-selection-coding-system 'utf-8)
  (prefer-coding-system 'utf-8))
