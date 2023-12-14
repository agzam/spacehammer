local Spacehammer = {
  name = "Spacehammer",
  version = "3.0.0",
  author = "Ag Ibragimov",
  license = "MIT",
  homepage = "https://github.com/agzam/spacehammer"
}

function Spacehammer:init()
  local scriptPath = hs.spoons.scriptPath()

  package.path = package.path .. ";" .. scriptPath .. "?.lua;" .. scriptPath .. "?/init.lua;"
  package.cpath = package.cpath .. ";" .. scriptPath .. "?.so;"

  fennel = require("spacehammer.vendor.fennel")
  fennel.path = scriptPath .. "?.fnl;" .. scriptPath .. "?/init.fnl;" .. fennel.path
  fennel['macro-path'] = scriptPath .. "?.fnl;" .. scriptPath .. "?/init-macros.fnl;" .. scriptPath .. "?/init.fnl;" .. fennel.path
  table.insert(package.loaders or package.searchers, fennel.searcher)
end

function Spacehammer:start()
  require('spacehammer.core')
  hs.alert.show("Spacehammer config loaded")
end

return Spacehammer
