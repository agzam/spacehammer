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

(fn read-secrets
  []
  (let [run-str "/usr/local/MacGPG2/bin/gpg2 -q --for-your-eyes-only --no-tty -d ./.secrets.json.gpg"
        file (io.popen run-str)
        out (: file :read "*l")]
    (: file :close)
    (when out (hs.json.decode out))))

{:read read-secrets}
