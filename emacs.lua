local emacs = {}

local capture = function(isNote)
  local key = ""
  if isNote then
    key = "\"c\"" -- key is a string associated with org-capture template
  end
  local currentApp = hs.window.focusedWindow();
  local pid = "\"" .. currentApp:pid() .. "\" "
  local title = "\"" .. currentApp:title() .. "\" "
  hs.timer.delayed.new(0.1, function()
                         hs.execute("/usr/local/bin/emacsclient" ..
                                    " -c -F '(quote (name . \"capture\"))'" ..
                                    " -e '(activate-capture-frame " .. pid .. title .. key .. " )'")
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
  hotkeyModal:bind("", "t", function()
                     hs.alert.show(hs.window.focusedWindow():pid(), 2)
                            end)
end

emacs.switchToApp = function(pid, title)
  local app = hs.application.applicationForPID(pid)
  if app then
    app:activate()
  end
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
