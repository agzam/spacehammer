local apps = {}
local multimedia = require "multimedia"
local windows = require "windows"
local slack = require "slack"

apps.addState = function(modal)
  modal.addState("apps", {
                   init = function(self, fsm)
                     self.modal = hs.hotkey.modal.new()
                     modal.displayModalText "e\t emacs\ng \t chrome\n i\t iTerm\n s\t slack\n b\t brave"
                     self.modal:bind("","escape", function() fsm:toIdle() end)
                     self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
                     for key, app in pairs({
                         i = "iTerm2",
                         g = "Google Chrome",
                         b = "Brave",
                         e = "Emacs",
                         m = multimedia.musicApp}) do
                       self.modal:bind("", key, function() windows.activateApp(app); fsm:toIdle() end)
                     end

                     slack.bind(self.modal, fsm)
                     self.modal:enter()
  end})
end

return apps
