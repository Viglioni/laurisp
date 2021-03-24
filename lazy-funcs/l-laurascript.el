;;
;; @author Laura Viglioni
;; 2020
;; GNU Public License 3.0
;;

;;
;; tide related functions
;;

(require 'helm)
(require 'functional)
(require 'l-string)
(require 'l-general)


;;
;; Import JS libs from package.json
;;

;;;###autoload
(defun laurascript--get-project-libs ()
  "get all libs from package.json dependencies, it searches from
   this file in project root or current dir"
  (let ((pjson-file (join-path (or (projectile-project-root) ".") "package.json")))
    (throw-if (not (file-exists-p pjson-file)) "package.json not found!")
    (-> pjson-file
        ((get-string-from-file)
         (regex-matches (rx "\"dependencies"  (+ (not "}")) "}"))
         (head)
         (replace-regexp-in-string (rx "\"dependencies\": {") "")
         (regex-matches (rx line-start (+ (not ":")) ":"))
         (mapcar (curry replace-regexp-in-string (rx (or "\"" ":" " " "" "\n")) ""))
         (funcall (lambda (lst) (sort lst #'string<)))))))

;;;###autoload
(defun laurascript--insert-import (lib-name import-name)
  "Inserts 'import $import-name from $lib-name' on the first
   empty line of buffer"
  (insert-on-fst-empty-line
   (concat "import " import-name " from \"" lib-name "\"\n")
   (point)))

;;;###autoload
(defun laurascript--helm-import-lib (lib-name)
  (helm
   :prompt "Import lib as: "
   :volatile t
   :sources (helm-build-dummy-source "Import name source"
              :action (curry laurascript--insert-import lib-name))))

;;;###autoload
(defun laurascript--helm-libs-source ()
  (helm-build-sync-source "Libs Source"
    :volatile t
    :multiline nil
    :candidates (laurascript--get-project-libs)
    :action 'laurascript--helm-import-lib ))

;;;###autoload
(defun ls-import-js-libs ()
  "Add 'import $import-name from $lib-name' on the first empty line.
   It searches on project root directory or current directory for 
   package.json and searches for all libs inside its dependencies"
  (interactive)
  (helm :prompt "Choose a lib to import: "
        :sources (laurascript--helm-libs-source)
        :buffer "*helm buffer source*"))







