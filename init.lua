require "preload"
local modal = require "modal"
local windows = require "windows"
local multimedia = require "multimedia"
local apps = require "apps"

require "preview-app"

hs.hints.style = "vimperator"
hs.hints.showTitleThresh = 4
hs.hints.titleMaxSize = 10
hs.hints.fontSize = 30

windows.addState(modal)
apps.addState(modal)
multimedia.addState(modal)

local stateMachine = modal.createMachine()
stateMachine:toMain()

hs.alert.show("Config Loaded")
