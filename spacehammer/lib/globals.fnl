(local fennel (require :spacehammer.vendor.fennel))
(local {: map} (require :spacehammer.lib.functional))
(require-macros :spacehammer.lib.advice.macros)

(global pprint
        (fn pprint
          [...]
          "
          Similar to print but formats table arguments for human readability
          "
          (print
           (table.unpack
            (map #(match (type $1)
                    "table" (fennel.view $1)
                    _       $1)
                 [...])))))

"
alert :: str, { style }, seconds -> nil
Shortcut for showing an alert on the primary screen for a specified duration
Takes a message string, a style table, and the number of seconds to show alert
Returns nil. This function causes side-effects.
"
(global alert
        (afn
         alert
         [str style seconds]
         "
         Global alert function used for spacehammer modals and reload
         alerts after config reloads
         "
         (hs.alert.show str
                        style
                        (hs.screen.primaryScreen)
                        seconds)))

(global fw hs.window.focusedWindow)
