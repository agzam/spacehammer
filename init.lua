hs.alert.show("Spacehammer config loaded")

-- Add luarocks/fennel installation paths for Homebrew and user-local trees.
-- Hammerspoon embeds a specific version of Lua (5.4 at time of writing), but luarocks may
-- install under any Lua version and fennel is directly packaged by homebrew, so we search
-- all available versions within both Homebrew prefixes and ~/.luarocks.
local prefixes = {"/opt/homebrew", "/usr/local", os.getenv("HOME") .. "/.luarocks"}

local function subdirs(path)
   local result = {}
   local pathAttrs = hs.fs.attributes(path)

   if pathAttrs and pathAttrs["mode"] == "directory" then
     local iter, dir_obj = hs.fs.dir(path)
     if iter then
       for entry in iter, dir_obj do
         if entry ~= "." and entry ~= ".." then
           table.insert(result, entry)
         end
       end
     end
   end
   return result
end

for _, base in ipairs(prefixes) do
   for _, ver in ipairs(subdirs(base .. "/share/lua")) do
      package.path = package.path .. ";" .. base .. "/share/lua/" .. ver .. "/?.lua;" .. base .. "/share/lua/" .. ver .. "/?/init.lua"
   end
   for _, ver in ipairs(subdirs(base .. "/lib/lua")) do
      package.cpath = package.cpath .. ";" .. base .. "/lib/lua/" .. ver .. "/?.so"
   end
end

fennel = require("fennel")
local home = os.getenv("HOME")
fennel.path = fennel.path .. ";" .. home .. "/.hammerspoon/?.fnl;" .. home .. "/.hammerspoon/?/init.fnl"
fennel["macro-path"] = fennel["macro-path"] .. ";" .. home .. "/.hammerspoon/?.fnl;" .. home .. "/.hammerspoon/?/init.fnl"
table.insert(package.loaders or package.searchers, fennel.searcher)

require "core"
