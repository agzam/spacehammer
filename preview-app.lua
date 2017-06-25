local windows = require "windows"
local keybindings = require "keybindings"

local previewAppHotKeys = {}

-- j/k for scrolling up and down
for k, dir in pairs({j = -5, k = 5}) do
  local function scrollFn()
    windows.setMouseCursorAtApp("Preview")
    hs.eventtap.scrollWheel({0, dir}, {})
  end
  table.insert(previewAppHotKeys, hs.hotkey.new("", k, scrollFn, nil, scrollFn))
end

-- enable/disable hotkeys
keybindings.appSpecific["Preview"] = {
  activated = function()
    for _,k in pairs(previewAppHotKeys) do
      keybindings.activateAppKey("Preview", k)
    end
  end,
  deactivated = function() keybindings.deactivateAppKeys("Preview") end,
}
