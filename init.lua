--  Copyright (c) 2017-2020 Ag Ibragimov & Contributors
--
--  Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
--
--  Contributors:
--      Jay Zawrotny <jayzawrotny@gmail.com>
--
--  URL: https://github.com/agzam/spacehammer
--
--  License: MIT
--


hs.alert.show("Spacehammer config loaded")

-- Support upcoming 5.4 release and also use luarocks' local path
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.4/?.lua;" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.4/?/init.lua"
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.luarocks/lib/lua/5.4/?.so"
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?.lua;" .. os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?/init.lua"
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.luarocks/lib/lua/5.3/?.so"

fennel = require("fennel")
table.insert(package.loaders or package.searchers, fennel.searcher)

require "core"
