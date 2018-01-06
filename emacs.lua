local emacs = {}

local capture = function(isNote)
  local key = ""
  if isNote then
    key = "\"z\"" -- key is a string associated with org-capture template
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
  hotkeyModal:bind("", "z", function()
                     fsm:toIdle()
                     capture(true) -- note on currently clocked in
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
                     modal.displayModalText "c \tcapture\nz\tnote"

                     self.hotkeyModal:bind("","escape", function() fsm:toIdle() end)
                     self.hotkeyModal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)

                     bind(self.hotkeyModal, fsm)
                     self.hotkeyModal:enter()
                   end
  })
end

-- whenever I connect to a different display my Emacs frame gets screwed. This is a temporary fix (until) I figure out Display Profiles feature
-- the relevant elisp function couldn be found here: https://github.com/agzam/dot-spacemacs/blob/master/layers/ag-general/funcs.el#L36
local function fixEmacsFrame()
  hs.execute("/usr/local/bin/emacsclient" .. " -e '(ag/fix-frame)'")
end
hs.screen.watcher.new(function()
    hs.alert("Screen watcher")
    fixEmacsFrame()
    end
):start()
hs.caffeinate.watcher.new(function(ev)
    local mds = { hs.caffeinate.watcher.systemDidWake,
                  hs.caffeinate.watcher.screensDidUnlock,
                  hs.caffeinate.watcher.sessionDidBecomeActive }
    if hs.fnutils.contains(mds, ev) then
      hs.alert("caffeinate event " .. ev)
      fixEmacsFrame()
    end
end):start()

return emacs
