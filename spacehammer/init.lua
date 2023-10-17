hs.alert.show("Spacehammer config loaded")

fennel = require("spacehammer.vendor.fennel")
table.insert(package.loaders or package.searchers, fennel.searcher)

require "core"
