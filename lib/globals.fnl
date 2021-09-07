(local fennel (require :fennel))
(local {: map} (require :lib.functional))

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
