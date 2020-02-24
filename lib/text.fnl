;; Copyright (c) 2017-2020 Ag Ibragimov & Contributors
;;
;;; Author: Jay Zawrotny <jayzawrotny@gmail.com>
;;
;;; URL: https://github.com/agzam/spacehammer
;;
;;; License: MIT
;;

(local {:map    map
        :merge  merge
        :reduce reduce} (require :lib.functional))

"
These functions will align items in a modal menu based on columns.
This makes the modal look more organized because the keybindings, separator, and
action are all vertically aligned based on the longest value of each column.
"

(fn max-length
  [items]
  "
  Finds the max length of each  value in a column
  Takes a list of key value pair lists
  Returns the maximum length in characters.
  "
  (reduce
   (fn [max [key _]]  (math.max max (length key)))
   0
   items))

(fn pad-str
  [char max str]
  "
  Pads a string to the max length with the specified char concatted to str.
  Takes the char string to pad with typically \" \", the max size of the column,
  and the str to concat to.
  Returns the padded string

  Example:
  (pad-str \".\" 6 \"hey\")
  ;; => \"hey...\"
  "
  (let [diff (- max (# str))]
    (.. str (string.rep char diff))))


(fn align-columns
  [items]
  "
  Align the key column of the menu items by padding out each
  key string with a space to match the longest item key string.
  Takes a list of modal menu items
  Returns a list of veritcally aligned row strings
  "
  (let [max (max-length items)]
    (map
     (fn [[key action]]
       (.. (pad-str " " max key) "     " action))
     items)))

{:align-columns align-columns}
