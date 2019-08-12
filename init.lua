hs.alert.show("Spacehammer config loaded")

fennel = require("fennel")
table.insert(package.loaders or package.searchers, fennel.searcher)

require "core"
