local windows = require "windows"
local previewAppKeys = {}

hs.fnutils.each({{key = "j", dir = "down" }, { key = "k", dir = "up"}}, function(k)
    local function scrollFn()
      hs.eventtap.keyStroke({""}, k.dir)
    end
    -- pressing `j, k` for scrolling
    previewAppKeys[{key = k}] = hs.hotkey.new("", k.key, scrollFn, nil, scrollFn)
end)

hs.window.filter.new('Preview')
  :subscribe(hs.window.filter.windowFocused, function()
               -- Preview app is in focus
               hs.fnutils.each(previewAppKeys, function(k) k:enable() end)
            end)
  :subscribe(hs.window.filter.windowUnfocused,function()
               -- Preview app lost the focus
               hs.fnutils.each(previewAppKeys, function(k) k:disable() end)
            end)
