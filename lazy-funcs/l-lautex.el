;;
;; @author Laura Viglioni
;; 2021
;; GNU Public License 3.0
;;

;;
;; org-latex-pdf related functions
;;

(require 'helm)

;;
;; common functions
;;

;;;###autoload
(defun lautex--get-org-buffer-name (src-buffer)
  (replace-regexp-in-string "\\[" "" (nth 2 (split-string src-buffer " "))))

;;;###autoload
(defun lautex--get-org-file-name ()
  "If in a edit-special buffer, return the org one,
   else return the buffer it was called"
  (or (buffer-file-name)
      (-> (buffer-name)
         ((lautex--get-org-buffer-name)
          (get-buffer)
          (buffer-file-name)))))

;;;###autoload
(defun lautex--get-text (regexp-prefix regexp-suffix str)
  "returns string between two regex prefixes"
  (-> str
     ((replace-regexp-in-string regexp-prefix "")
      (replace-regexp-in-string regexp-suffix ""))))

;;;###autoload
(defun lautex--command (command-name arg)
  "return string \\command-name{arg}"
  (concat "\\" command-name "{" arg "}"))

;;;###autoload
(defun lautex--insert-command (command-name arg)
  "insert \\command-name{arg}"
  (insert (lautex--command command-name arg)))

;;
;;  inserting LaTeX enviroment in org mode
;;  and editing them in special mode
;;

(defvar lautex--env-names
  (sort '("text" "theorem" "definition" "remark" "example" "proposition" "figure" "Table"  "description" "enumerate" "itemize" "list"  "math" "displaymath" "split" "array" "eqnarray" "equation" "equation*" "Matrix" "environments" "Cases" "align" "align*" "alignat" "environments" "center" "flushleft" "flushright" "minipage" "quotation" "quote" "verbatim" "verse" "tabbing" "tabular" "Thebibliography" "Titlepage") 'string<))


;;;###autoload
(defun lautex--insert-env (env-name)
  "inserts LaTeX environment"
  (insert (concat
           (lautex--command "begin" env-name)
           "\n\n"
           (lautex--command "end" env-name))))

(setq lautex--helm-env-sources
      (helm-build-sync-source "Environment"
          :candidates 'lautex--env-names
          :action 'lautex--insert-env))

(setq lautex--helm-env-sources-fallback
      (helm-build-dummy-source "Environment"
        :action 'lautex--insert-env))

;;;###autoload
(defun LauTeX-org-env ()
  "inserts LaTeX env and opens edit special"
 (interactive)
  (if (eq 'org-mode major-mode)
      (progn
        (helm
         :history t
         :volatile nil
         :sources '(lautex--helm-env-sources lautex--helm-env-sources-fallback))
        (org-edit-special)
        (previous-line)
        (spacemacs/indent-region-or-buffer))))

;;;###autoload
(defun LauTeX-org-env-exit ()
  "exits edit special and toggle latex fragment to image"
  (interactive)
  (org-edit-src-exit)
  (org-clear-latex-preview (point) (inc (point)))
  (org-toggle-latex-fragment))

;;;###autoload
(defun LauTeX-preview-org-env ()
  "preview on org buffer latex changes in special edit buffer"
  (interactive)
  (let* ((edit-buff (buffer-name))
         (original-buf (lautex--get-org-buffer-name edit-buff))
         (buffer-exists (bool (get-buffer original-buf))))
    (if buffer-exists
        (progn
          (org-edit-src-save)
          (switch-to-buffer original-buf)
          (org-clear-latex-preview (point) (+ 1 (point)))
          (org-toggle-latex-fragment)
          (switch-to-buffer edit-buff))
      (print (concat "Buffer " original-buf " does not exists!")))))


;;
;; Reference existing labels
;;
(defvar lautex--regex-prefix-label  ".*label\{"
  "regex prefix for \\label{...}")

(defvar lautex--regex-sufix-label  "\}.*" 
  "regex sufix for \\label{...}")

;;;###autoload
(defun lautex--get-label (line)
  "get string %s in .*\\label{%s}.*"
  (lautex--get-text
   lautex--regex-prefix-label
   lautex--regex-sufix-label
   line))

;;;###autoload
(defun lautex--insert-reference (label)
  "insert \\ref{label} on text"
  (let ((label-type (capitalize (lautex--label-type label))))
    (unless (string-empty-p label-type)
      (insert (concat label-type "~"))))
  (lautex--insert-command "ref" label))

(setq mock-org "/Users/laura.viglioni/Personal/mestrado/eqm-text/eqm.org")

;;;###autoload
(defun lautex--label-type (label)
  (let* ((splitted (split-string label ":"))
         (label-type (if (= 2 (length splitted)) (head splitted) "")))
    (upcase label-type)))

;;;###autoload
(defun lautex--build-reference-candidate (match)
  (let* ((label (lautex--get-label match))
         (description (-> label
                  ((replace-regexp-in-string "[\\._-]" " ")
                   (replace-regexp-in-string ".*:" "")
                   (capitalize))))
         (label-type (lautex--label-type label))
         (full-description (if (string-empty-p label-type)
                               description
                             (string-join (list label-type description) ": "))))
    (cons full-description label)))



;;;###autoload
(defun lautex--reference-candidates ()
  "Get all labels from a org/latex file"
  (let* ((text (get-string-from-file  (lautex--get-org-file-name)))
         (matches (regex-matches "\\label\{.*\}" text)))
    (seq-map 'lautex--build-reference-candidate matches)))



;;;###autoload
(defun lautex--helm-label-source ()
  (helm-build-sync-source "Label Source"
    :candidates (lautex--reference-candidates)
    :action 'lautex--insert-reference))

;;;###autoload
(defun LauTeX-insert-reference ()
  (interactive)
  (helm :sources (lautex--helm-label-source)
        :buffer "*helm buffer source*"))


;;
;; Insert libs
;;
(defvar lautex--regex-bib-files "\\.bib$" "regex to match .bib files")

;;;###autoload
(defun lautex--insert-citation (citation)
  "insert \\ref{citation} on text"
  (lautex--insert-command "cite" citation))

;;;###autoload
(defun lautex--get-bib-files ()
  "get all .bib files in your project from your project root
   or where this function is called"
  (directory-files-recursively
   (or (projectile-project-root) default-directory)
   lautex--regex-bib-files))

;;;###autoload
(defun lautex--get-citation (line)
  "get string %s in .*\\label{%s}.*"
  (-> line
     ((replace-regexp-in-string "@[a-zA-Z]*\{" "")
      (replace-regexp-in-string "," "" ))))

(defun lautex--bib-citations (file-path)
  "get all citations from a given file"
  (-> (get-string-from-file file-path)
     ((regex-matches "@[a-zA-Z]*\{[a-z0-9A-Z].*,")
      (seq-map 'lautex--get-citation))))

;;;###autoload
(defun lautex--bib-info (line)
  "get info from a bib line"
  (-> line
     ((replace-regexp-in-string "[a-z]* ?= ?\{*" "")
      (replace-regexp-in-string "\}.*" ""))))

;;;###autoload
(defun lautex--bib-titles (file)
  (let* ((file-content (get-string-from-file file))
         (titles (regex-matches "title ?=.*" file-content)))
    (seq-map 'lautex--bib-info titles)))


;;;###autoload
(defun lautex--bib-authors (file)
  (let* ((file-content (get-string-from-file file))
         (authors (regex-matches "author ?=.*" file-content)))
    (seq-map 'lautex--bib-info authors)))


;;;###autoload
(defun lautex--bib-year (file)
  (let* ((file-content (get-string-from-file file))
         (year (regex-matches "year ?=.*" file-content)))
    (seq-map 'lautex--bib-info year)))


;;;###autoload
(defun lautex--form-candidates (file)
  (let ((citations (lautex--bib-citations file))
        (titles (lautex--bib-titles file))
        (years (lautex--bib-year file))
        (authors (lautex--bib-authors file)))
    (mapcar*
         (lambda (yea tit aut cit) (cons (format "(%s) %s\n%s" yea tit aut) cit))
        years titles authors citations)))



;;;###autoload
(defun lautex--citation-candidates ()
  "get all citation candidates of all bib files"
  (-> (lautex--get-bib-files)
     ((seq-map 'lautex--form-candidates)
      (apply 'append)
      (alist-sort-by-car))))

;;;###autoload
(defun lautex--helm-citation-source ()
  (helm-build-sync-source "Label Source"
    :volatile t
    :multiline t
    :candidates (lautex--citation-candidates)
    :action 'lautex--insert-citation))

;;;###autoload
(defun LauTeX-insert-citation ()
  (interactive)
  (helm :prompt "Choose a source to cite: "
        :sources (lautex--helm-citation-source)
        :buffer "*helm buffer source*"))



