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

fennel = require("fennel")
table.insert(package.loaders or package.searchers, fennel.searcher)

require "core"
