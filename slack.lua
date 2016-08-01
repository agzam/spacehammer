-- Improving Slack
-- as "Apps" modal lets you switch to Slack, and shows "Jump to" dialog box

-- Slack doesn't allow scrolling thread by using only keyboard -
--  this module introduces C-j, C-k bindings for scrolling
--  C-g - takes you to the end of thread

modalA:bind("", "s", function()
              hs.application.launchOrFocus("Slack")
              local app = hs.application.find("Slack")
              if app then
                app:activate()
                hs.timer.doAfter(0.2, highlighActiveWin)
                hs.eventtap.keyStroke({"cmd"}, "k")
                app:unhide()
              end

              exitModals()
end)

-- to correctly scroll the window, mouse pointer should be within the frame (otherwise it would scroll other windows that do not belong to Slack)
function setMouseCursorOnSlack()
  local sf = hs.application.find("Slack"):findWindow("Slack"):frame()
  local desired_point = hs.geometry.point(sf._x + sf._w - 20, sf._y + sf._h - 100) 
  hs.mouse.setAbsolutePosition(desired_point)
end

hs.window.filter.new('Slack')
  :subscribe(hs.window.filter.windowFocused,function()
               -- Slack on focus
               hs.fnutils.each(scrollKeys, function(k) k:enable() end)
               slackJumpToEnd = hs.hotkey.bind({"ctrl"}, "g",
                 function()
                   setMouseCursorOnSlack()
                   hs.eventtap.scrollWheel({0, -5000}, {}) -- from my experience this number is big enough to take you to the end of thread
                 end, nil, nil)
            end)
:subscribe(hs.window.filter.windowUnfocused,function()
             -- Slack lost focus
             hs.fnutils.each(scrollKeys, function(k) k:disable() end)
             slackJumpToEnd:disable()
          end)

scrollKeys = {}
slackJumpToEnd = {}

-- when Slack is active, pressing C-j, C-k should force to scroll discussion thread window up and down
hs.fnutils.each({{key = "j", dir = -3}, {key = "k", dir = 3}}, function(k)
    function scrollFn()
      setMouseCursorOnSlack()
      hs.eventtap.scrollWheel({0, k.dir}, {})
    end
    scrollKeys[k.key] = hs.hotkey.new({"ctrl"}, k.key, scrollFn, nil, scrollFn)
end)
