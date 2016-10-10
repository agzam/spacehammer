-- This module is to improve workflow in Slack
local windows = require "windows"
local slack = {}
local slackLocalKeys = {}
local slackJumpToEnd = {}

slack.bind = function(modal, fsm)
  -- Open "Jump to dialog immediately after jumping to Slack GUI through `Apps` modal"
  modal:bind("", "s", function()
                hs.application.launchOrFocus("Slack")
                local app = hs.application.find("Slack")
                if app then
                  app:activate()
                  hs.timer.doAfter(0.2, windows.highlighActiveWin)
                  hs.eventtap.keyStroke({"cmd"}, "k")
                  app:unhide()
                end

                fsm:toIdle()
  end)
end

-- Slack client doesn't allow convenient method to scrolling in thread with keyboard 
-- adding C-j, C-k bindings for scrolling

-- to correctly scroll in Slack's thread window, the mouse pointer have to be within its frame (otherwise it would scroll things in whatever app cursor is currently pointing at)
local function setMouseCursorOnSlack()
  windows.setMouseCursorAtApp "Slack"
end

hs.window.filter.new('Slack')
  :subscribe(hs.window.filter.windowFocused,function()
               -- Slack is in focus
               hs.fnutils.each(slackLocalKeys, function(k) k:enable() end)
               --  C-g - takes you to the end of thread
               slackJumpToEnd = hs.hotkey.bind({"ctrl"}, "g",
                 function()
                   setMouseCursorOnSlack()
                   hs.eventtap.scrollWheel({0, -5000}, {}) -- from my experience this number is big enough to take you to the end of thread
                 end, nil, nil)

               slackInsertEmoji = hs.hotkey.bind({"cmd"}, "i",
                 function()
                   hs.eventtap.keyStroke({"cmd", "shift"}, "\\")
                 end, nil, nil)
            end)
  :subscribe(hs.window.filter.windowUnfocused,function()
             -- Slack lost focus
             hs.fnutils.each(slackLocalKeys, function(k) k:disable() end)
             slackJumpToEnd:disable()
             slackInsertEmoji:disable()
          end)


-- when Slack is active ...
hs.fnutils.each({{key = "j", dir = -3}, {key = "k", dir = 3}}, function(k)
    local function scrollFn()
      setMouseCursorOnSlack()
      hs.eventtap.scrollWheel({0, k.dir}, {})
    end
    -- pressing C-j, C-k should force to scroll discussion thread window up and down
    slackLocalKeys[{key = k, mod = "ctrl"}] = hs.hotkey.new({"ctrl"}, k.key, scrollFn, nil, scrollFn)

    local function jumpItem()
      setMouseCursorOnSlack()
      if k.key == "j" then
        hs.eventtap.keyStroke({"alt"}, "down")
      elseif k.key == "k" then
        hs.eventtap.keyStroke({"alt"}, "up")
      end
    end

    -- pressing M-j, M-k for "previous/next item in the list"
    slackLocalKeys[{key = k, mod = "alt"}] = hs.hotkey.new({"alt"}, k.key, jumpItem, nil, jumpItem)
end)

return slack
