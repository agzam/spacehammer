(fn global-filter
  []
  "
  Filter that includes full-screen apps
  "
  (let [filter (hs.window.filter.new)]
    (: filter :setAppFilter :emacs {:allowRoles [:AXUnknown :AXStandardWindow]})))

{:global-filter global-filter}
