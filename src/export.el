(require 'ox-publish)

(setq org-export-global-macros
      '(("timestamp" . "@@html:<span class=\"timestamp\">[$1]</span>@@")
        ("loc" . "@@html:<span class=\"location\">[Location]</span>: $1@@")))

;; Project alist
(setq org-publish-project-alist
      '(("jutlandia-pages"
         :base-directory "pages/"
         :base-extension "org"
         :publishing-directory "."
         :recursive t
         :preserve-breaks t
         :publishing-function org-html-publish-to-html
         :org-html-preamble nil
         :html-postamble "")
        ("jutlandia-assets"
         :base-directory "posts/assets/"
         :base-extension "jpg\\|png\\|gif"
         :publishing-directory "assets/"
         :recursive t
         :publishing-function org-publish-attachment)
        ("jutlandia"
         :components ("jutlandia-pages"
                      "jutlandia-assets"))))

(org-publish "jutlandia" t)
