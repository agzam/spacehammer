-- This module is to improve keyboard oriented workflow in Slack
local windows = require "windows"
local keybindings = require "keybindings"
local module = {}

local function setMouseCursorOnSlack()
  windows.setMouseCursorAtApp("Slack")
end

local slackLocalHotkeys = {
  -- jump to end of thread on C-g
  hs.hotkey.bind({"ctrl"}, "g",
    function()
      setMouseCursorOnSlack()
      -- from my experience this number is big enough to take you to the end of thread
      hs.eventtap.scrollWheel({0, -5000}, {})
    end, nil, nil),
  -- add a reaction
  hs.hotkey.bind({"ctrl"}, "r",
    function()
      hs.eventtap.keyStroke({"cmd", "shift"}, "\\")
    end, nil, nil)
}

-- Slack client doesn't allow convenient method to scrolling in thread with keyboard
-- adding C-j|C-e, C-k|C-y bindings for scrolling up and down
for k,dir in pairs({j = -3, k = 3, e = -3, y = 3}) do
  local function scrollFn()
    -- to correctly scroll in Slack's thread window, the mouse pointer have to be within its frame (otherwise it would scroll things in whatever app cursor is currently pointing at)
    setMouseCursorOnSlack()
    hs.eventtap.scrollWheel({0, dir}, {})
  end

  table.insert(slackLocalHotkeys, hs.hotkey.new({"ctrl"}, k, scrollFn, nil, scrollFn))
end

-- C-o/C-i for back and forth in history
for k, dir in pairs({o = "[", i = "]"}) do
  local back_forward = function() hs.eventtap.keyStroke({"Cmd"}, dir) end
  table.insert(slackLocalHotkeys, hs.hotkey.new({"Ctrl"}, k, back_forward, nil, back_forward))
end

-- C-n|C-p - for up and down (instead of using arrow keys)
for k, dir in pairs({p = "up", n = "down"}) do
  local function upNdown()
    hs.eventtap.keyStroke({}, dir)
  end

  table.insert(slackLocalHotkeys, hs.hotkey.new({"ctrl"}, k, upNdown, nil, upNdown))
end

-- enable/disable hotkeys
keybindings.appSpecific["Slack"] = {
  activated = function()
    for _,k in pairs(slackLocalHotkeys) do
      keybindings.activateAppKey("Slack", k)
    end
  end,
  deactivated = function() keybindings.deactivateAppKeys("Slack") end
}

module.bind = function(modal, fsm)
  -- Open "Jump to dialog immediately after jumping to Slack GUI through `Apps` modal"
  modal:bind("", "s", function()
               hs.application.launchOrFocus("Slack")
               local app = hs.application.find("Slack")
               if app then
                 app:activate()
                 hs.timer.doAfter(0.2, windows.highlighActiveWin)
                 hs.eventtap.keyStroke({"cmd"}, "t")
                 app:unhide()
               end

               fsm:toIdle()
  end)
end

return module
