local emacs = {}

local capture = function(isNote)
  local key = ""
  if isNote then
    key = "\"z\"" -- key is a string associated with org-capture template
  end
  local currentApp = hs.window.focusedWindow();
  local pid = "\"" .. currentApp:pid() .. "\" "
  local title = "\"" .. currentApp:title() .. "\" "
  local runStr = "/usr/local/bin/emacsclient" .. " -c -F '(quote (name . \"capture\"))'" .. " -e '(activate-capture-frame " .. pid .. title .. key .. " )'"

  hs.timer.delayed.new(0.1, function() io.popen(runStr) end):start()
end

local bind = function(hotkeyModal, fsm)
  hotkeyModal:bind ("", "c", function()
                      fsm:toIdle()
                      capture() end)
  hotkeyModal:bind("", "z", function()
                     fsm:toIdle()
                     capture(true) -- note on currently clocked in
  end)
end

-- don't remove - this is callable from Emacs
emacs.switchToApp = function(pid)
  local app = hs.application.applicationForPID(pid)
  if app then
    app:activate()
  end
end

-- don't remove - this is callable from Emacs
emacs.switchToAppAndPasteFromClipboard = function(pid)
  local app = hs.application.applicationForPID(pid)
  if app then
    app:activate()
    app:selectMenuItem({"Edit", "Paste"})
  end
end

emacs.addState = function(modal)
  modal.addState("emacs", {
                   from = "*",
                   init = function(self, fsm)
                     self.hotkeyModal = hs.hotkey.modal.new()
                     modal.displayModalText "c \tcapture\nz\tnote"

                     self.hotkeyModal:bind("","escape", function() fsm:toIdle() end)
                     self.hotkeyModal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)

                     bind(self.hotkeyModal, fsm)
                     self.hotkeyModal:enter()
  end})
end

emacs.editWithEmacs = function()
  local currentApp = hs.window.focusedWindow():application()
  hs.eventtap.keyStroke({"cmd"}, "a")
  hs.eventtap.keyStroke({"cmd"}, "c")

  local pid = "\"" .. currentApp:pid() .. "\" "
  local title = "\"" .. currentApp:title() .. "\" "

  local runStr = "/usr/local/bin/emacsclient" .. " -c -F '(quote (name . \"edit\"))'" .. " -e '(ag/edit-with-emacs" .. pid .. title .. " )'";

  io.popen(runStr)
end

emacs.enableEditWithEmacs = function()
  emacs.editWithEmacsKey =
    emacs.editWithEmacsKey or hs.hotkey.new({"cmd", "ctrl"}, "o", nil, emacs.editWithEmacs)
  emacs.editWithEmacsKey:enable()
end

emacs.disableEditWithEmacs = function()
  emacs.editWithEmacsKey:disable()
end

-- whenever I connect to a different display my Emacs frame gets screwed. This is a temporary fix (until) I figure out Display Profiles feature
-- you can find the relevant elisp function here: https://github.com/agzam/dot-spacemacs/blob/master/layers/ag-general/funcs.el#L36
local function fixEmacsFrame()
  io.popen("/usr/local/bin/emacsclient" .. " -e '(ag/fix-frame)'")
end

hs.screen.watcher.newWithActiveScreen(function(isActiveScreenChanged)
    if isActiveScreenChanged == nil then
      hs.alert("Screen watcher")
      fixEmacsFrame()
    end
end):start()

return emacs
