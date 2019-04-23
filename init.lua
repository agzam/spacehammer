-- require "preload"
-- local modal = require "modal"
-- require "preview-app"

hs.hints.style = "vimperator"
hs.hints.showTitleThresh = 4
hs.hints.titleMaxSize = 10
hs.hints.fontSize = 30

-- require("apps").addState(modal)
-- require("multimedia").addState(modal)
-- require("emacs").addState(modal)

-- local stateMachine = modal.createMachine()
-- stateMachine:toMain()

hs.alert.show("Config Loaded")

fennel = require("fennel")
table.insert(package.loadeers or package.searchers, fennel.searcher)

require "preload"

local modal = require "modal"

require("windows").addState(modal)
local stateMachine = modal.createMachine()
stateMachine:toMain()
