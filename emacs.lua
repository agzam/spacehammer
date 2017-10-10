local emacs = {}

local capture = function(isNote)
  local key = ""
  if isNote then
    key = "\"c\""
  end
  hs.timer.delayed.new(0.1, function()
                         hs.execute("/usr/local/bin/emacsclient -c -F '(quote (name . \"capture\"))' -e '(activate-capture-frame " .. key ..")'")
  end):start()
end

local bind = function(hotkeyModal, fsm)
  hotkeyModal:bind("", "c", function()
                     fsm:toIdle()
                     capture()
  end)
  hotkeyModal:bind("", "n", function()
                     fsm:toIdle()
                     capture(true) -- note on currently clocked in
  end)
end

emacs.addState = function(modal)
  modal.addState("emacs", {
                   init = function(self, fsm)
                     self.hotkeyModal = hs.hotkey.modal.new()
                     modal.displayModalText "c \tcapture\nn\tnote"

                     self.hotkeyModal:bind("","escape", function() fsm:toIdle() end)
                     self.hotkeyModal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)

                     bind(self.hotkeyModal, fsm)
                     self.hotkeyModal:enter()
                   end
  })
end

return emacs
