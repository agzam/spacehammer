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

function hsAppWatcher(appName, eventType, appObject)
  if (eventType == hs.application.watcher.activated) then
    if (appName == "Slack") then
      hs.fnutils.each(scrollKeys, function(k) k:enable() end)
    else
      hs.fnutils.each(scrollKeys, function(k) k:disable() end)
    end
  end
end

scrollKeys = {}
hs.fnutils.each({{key = "e", dir = -3}, {key = "y", dir = 3}}, function(k)
    function scrollFn()
      hs.eventtap.scrollWheel({0, k.dir}, {})
    end
    scrollKeys[k.key] = hs.hotkey.new({"ctrl"}, k.key, scrollFn, nil, scrollFn)
end)

local appWatcher = hs.application.watcher.new(hsAppWatcher)
appWatcher:start()

