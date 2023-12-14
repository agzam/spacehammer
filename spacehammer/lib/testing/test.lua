--test.lua
-- A script to run fennel files as tests passed in as cli args

local scriptPath = _cli.args[2] .. "/"

if _cli.args[3] == nil then
  print("Need to specify tests")
  return
end

-- package.path = package.path .. ";" .. scriptPath .. "?.lua;" .. scriptPath .. "?/init.lua;"
-- package.cpath = package.cpath .. ";" .. scriptPath .. "?.so;"
package.path = scriptPath .. "?.lua;" .. scriptPath .. "?/init.lua;" .. package.path .. ";"
package.cpath = scriptPath .. "?.so;" .. package.cpath
print("Package path in test.lua") -- DELETEME
print(package.path) -- DELETEME

-- fennel = require("fennel")
fennel = require("spacehammer.vendor.fennel")
fennel.path = scriptPath .. "?.fnl;" .. scriptPath .. "?/init.fnl;"
-- fennel.path = scriptPath .. "?.fnl;" .. scriptPath .. "?/init.fnl;" .. fennel.path
fennel["macro-path"] = scriptPath .. "?.fnl;" .. scriptPath .. "?/init-macros.fnl;" .. scriptPath .. "?/init.fnl;"
-- fennel["macro-path"] = scriptPath .. "?.fnl;" .. scriptPath .. "?/init-macros.fnl;" .. scriptPath .. "?/init.fnl;" .. fennel.path
print("Fennel path in test.lua") -- DELETEME
print(fennel.path) -- DELETEME

table.insert(package.loaders or package.searchers, fennel.searcher)

print("Loading test-runner")
-- local testRunner = fennel.dofile("../lib/testing/test-runner.fnl")
-- local testRunner = require("spacehammer.lib.testing.assert")
local testRunner = require("spacehammer.lib.testing.test-runner")
print(testRunner) -- DELETEME
-- TODO: Knock off the first arg, which is the base script path
testRunner["load-tests"](_cli.args)
return {}
