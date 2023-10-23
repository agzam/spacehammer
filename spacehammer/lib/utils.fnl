(fn global-filter
  []
  "
  Filter that includes full-screen apps
  "
  (let [filter (hs.window.filter.new)]
    (: filter :setAppFilter :Emacs {:allowRoles [:AXUnknown :AXStandardWindow :AXDialog :AXSystemDialog]})))

{:global-filter global-filter}
