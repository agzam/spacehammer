hs.alert.show("Spacehammer config loaded")

-- Support upcoming 5.4 release and also use luarocks' local path
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.4/?.lua;" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.4/?/init.lua"
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.luarocks/lib/lua/5.4/?.so"
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?.lua;" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?/init.lua"
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.luarocks/lib/lua/5.3/?.so"

fennel = require("fennel")
fennel_path = os.getenv("HOME") .. "/.spacehammer/?.fnl" .. ";" .. os.getenv("HOME") .. "/.hammerspoon/?.fnl" .. ";" .. os.getenv("HOME") .. "/.hammerspoon/?/init.fnl"
fennel.path = fennel_path
fennel["macro-path"] = fennel_path
table.insert(package.loaders or package.searchers, fennel.makeSearcher({ path = fennel_path }))
table.insert(fennel.macroSearchers, fennel.makeSearcher({ path = fennel_path }))

require "core"
