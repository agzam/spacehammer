--test.lua
-- A script to run fennel files as tests passed in as cli args

local scriptPath = _cli.args[2] .. "/"

if _cli.args[3] == nil then
  print("Need to specify tests")
  return
end

package.path = package.path .. ";" .. scriptPath .. "?.lua;" .. scriptPath .. "?/init.lua;"
package.cpath = package.cpath .. ";" .. scriptPath .. "?.so;"

fennel = require("spacehammer.vendor.fennel")
fennel.path = scriptPath .. "?.fnl;" .. scriptPath .. "?/init.fnl;"
fennel["macro-path"] = scriptPath .. "?.fnl;" .. scriptPath .. "?/init-macros.fnl;" .. scriptPath .. "?/init.fnl;"

table.insert(package.loaders or package.searchers, fennel.searcher)

local testRunner = require("spacehammer.lib.testing.test-runner")
testRunner["load-tests"](_cli.args)
