local Spacehammer = {
  name = "Spacehammer",
  version = "3.0.0",
  author = "Ag Ibragimov",
  license = "MIT",
  homepage = "https://github.com/agzam/spacehammer"
}

Spacehammer.paths = {}

function Spacehammer:init()
  local fennelPath = hs.spoons.resourcePath("vendor/fennel.lua")
  Spacehammer.paths.fennel = fennelPath
end

function Spacehammer:start()
  local envPath = hs.spoons.resourcePath("spacehammer/env.lua")
  local env = dofile(envPath)

  _G['fennel-installed'] = nil
  require('spacehammer.core')
  hs.alert.show("Spacehammer config loaded")
end

return Spacehammer
