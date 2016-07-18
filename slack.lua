-- Improving Slack
-- as "Apps" modal lets you switch to Slack, and shows "Jump to" dialog box
-- Slack doesn't allow scrolling thread by using only keyboard -
--  this module introduces C-e, C-y bindings for scrolling 

modalA:bind("", "s", function()
              hs.application.launchOrFocus("Slack")
              local app = hs.appfinder.appFromName("Slack")
              if app then
                app:activate()
                hs.timer.doAfter(0.2, highlighActiveWin)
                hs.eventtap.keyStroke({"cmd"}, "k")
                app:unhide()
              end

              exitModals()
end)

local app = hs.appfinder.appFromName("Slack")

hs.fnutils.each({{key = "e", dir = 3}, {key = "y", dir = -3}}, function(i)
    local scrollFn = function()
      local app = fw():application()
      if app:title() == "Slack" then
        hs.eventtap.scrollWheel({0, i.dir}, {}) -- scroll down
      end
    end

    hs.hotkey.bind({"ctrl"}, i.key, scrollFn, nil, scrollFn)
end)

