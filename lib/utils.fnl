;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;;
;;; Contributors:
;;   Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

(fn global-filter
  []
  "
  Filter that includes full-screen apps
  "
  (let [filter (hs.window.filter.new)]
    (: filter :setAppFilter :Emacs {:allowRoles [:AXUnknown :AXStandardWindow :AXDialog :AXSystemDialog]})))

(global add-advice!
  (fn [name where advice]
    (let [where-tag (.. "__" (tostring where))]
    (print "Adding advice to " name) ; DELETEME
      ;; TODO: Accept symbol
      ;; TODO: Support more than one per 'where'?
      (tset _G (.. name where-tag) advice))))

(fn remove-advice!
  [name where]
  (let [where-tag (.. "__" (tostring where))]
      (tset _G (.. name where-tag) nil)))

{: add-advice!
 : remove-advice!
 :global-filter global-filter}
