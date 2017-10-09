require "preload"
local keybindings = require "keybindings"
local machine = require "statemachine"
local windows = require "windows"
local slack = require "slack"
local multimedia = require "multimedia"
local modal = require "modal"

require "preview-app"

hs.hints.style = "vimperator"
hs.hints.showTitleThresh = 4
hs.hints.titleMaxSize = 10
hs.hints.fontSize = 30

modal.addState("windows", {
                 init = function(self, fsm)
                   self.modal = hs.hotkey.modal.new()
                   modal.displayModalText("cmd + hjkl \t jumping\nhjkl \t\t\t\t halves\nalt + hjkl \t\t increments\nshift + hjkl \t resize\nn, p \t next, prev screen\ng \t\t\t\t\t grid\nm \t\t\t\t maximize\nu \t\t\t\t\t undo")
                   self.modal:bind("","escape", function() fsm:toIdle() end)
                   self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
                   windows.bind(self.modal, fsm)
                   self.modal:enter()
end})

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

modal.addState("media", {
                 init = function(self, fsm)
                   self.modal = hs.hotkey.modal.new()
                   modal.displayModalText "h \t previous track\nl \t next track\nk \t volume up\nj \t volume down\ns \t play/pause\na \t launch player"

                   self.modal:bind("","escape", function() fsm:toIdle() end)
                   self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)

                   multimedia.bind(self.modal, fsm)
                   self.modal:enter()
end})

local stateMachine = modal.createMachine()
stateMachine:toMain()

hs.alert.show("Config Loaded")
