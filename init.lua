hs.alert.show("Spacehammer config loaded")

-- Add luarocks/fennel installation paths for Homebrew and user-local trees.
-- Hammerspoon embeds a specific version of Lua (5.4 at time of writing), but luarocks may
-- install under any Lua version and fennel is directly packaged by homebrew, so we search
-- all common versions at both Homebrew prefixes and ~/.luarocks.
local installation_prefixes = {"/opt/homebrew", "/usr/local", os.getenv("HOME") .. "/.luarocks"}
local lua_versions = {"5.1", "5.3", "5.4", "5.5"}
for _, base in ipairs(installation_prefixes) do
  for _, ver in ipairs(lua_versions) do
    package.path  = package.path  .. ";" .. base .. "/share/lua/" .. ver .. "/?.lua;" .. base .. "/share/lua/" .. ver .. "/?/init.lua"
    package.cpath = package.cpath .. ";" .. base .. "/lib/lua/"   .. ver .. "/?.so"
  end
end

fennel = require("fennel")
table.insert(package.loaders or package.searchers, fennel.searcher)

require "core"
