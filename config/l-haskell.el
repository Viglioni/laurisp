;;
;; @author Laura Viglioni
;; 2021
;; GNU Public License 3.0
;;

;;
;; haskell related functions
;;

(with-eval-after-load "haskell"
  (message "running exec path from shell...")
  (exec-path-from-shell-initialize)
  ;; (load-lib 'hs-lint)
  ;; (defun my-haskell-mode-hook ()
  ;;   (local-set-key "\C-cl" 'hs-lint))
  ;; (add-hook 'haskell-mode-hook 'my-haskell-mode-hook)
  ) 
