--test.lua
-- A script to run fennel files as tests passed in as cli args


fennel = require("spacehammer.vendor.fennel")

-- Support docstrings

local searcher = fennel.makeSearcher({
      useMetadata = true,
})

local testRunner = require "lib.testing.test-runner"

testRunner["load-tests"](_cli.args)
