(fn add-state [modal]
  (modal.addState
   :windows
   {:init (fn [self, fsm]
            (alert "in da windows init")
            (set self.hotkeyModal (hs.hotkey.modal.new))
            (modal.displayModalText
             "cmd + hjkl \t jumping\nhjkl \t\t\t\t halves\nalt + hjkl \t\t increments\nshift + hjkl \t resize\nn, p \t next, prev screen\ng \t\t\t\t\t grid\nm \t\t\t\t maximize\nu \t\t\t\t\t undo")

            ;; bind(self.hotkeyModal, fsm)
            (: self.hotkeyModal :enter)

            )})
  )

{:addState add-state}
