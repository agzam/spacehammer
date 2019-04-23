local apps = {}
local multimedia = require "multimedia"
local windows = require "windows"
local slack = require "slack"

apps.addState = function(modal)
  modal.addState("apps", {
                   from = "*",
                   init = function(self, fsm)
                     self.hotkeyModal = hs.hotkey.modal.new()
                     modal.displayModalText "e\t emacs\ng \t chrome\n f\t Firefox\n i\t iTerm\n s\t slack\n b\t brave"
                     self.hotkeyModal:bind("","escape", function() fsm:toIdle() end)
                     self.hotkeyModal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
                     for key, app in pairs({
                         i = "iTerm2",
                         g = "Google Chrome",
                         b = "Brave",
                         e = "Emacs",
                         f = "Firefox",
                         m = multimedia.musicApp})
                     do
                       self.hotkeyModal:bind("", key, function()
                                               windows.activateApp(app)
                                               fsm:toIdle()
                       end)
                     end

                     slack.bind(self.hotkeyModal, fsm)
                     self.hotkeyModal:enter()
  end})
end

return apps
