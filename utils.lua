local module = {}
local i

function module.tempNotify(timeout, notif)
  notif:send()
  hs.timer.doAfter(timeout, function() notif:withdraw() end)
end

function module.splitStr(str, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  i = 1
  for str in string.gmatch(str, "([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end

function module.strToTable(str)
  local t = {}
  for i = 1, #str do
    t[i] = str:sub(i, i)
  end
  return t
end

--- Filter that includes full-screen apps 
module.globalfilter = hs.window.filter.new()
  :setAppFilter('iTerm2', {allowRoles = '*', allowTitles = 0})
  :setAppFilter('Emacs', {allowRoles = '*', allowTitles = 1})

---- Function 
---- Applies specified functions for when window is focused and unfocused
----
---- Parameters:
----  
---- appNames - table of appNames
---- focusedFn - function applied when one of the apps listed is focused
---  unfocusedFn - function applied when one of the apps listed is unfocused 
---  ignore - reverses the order of the operation: apply given fns for any app except those listed in appNames
---
function module.applyAppSpecific(appNames, focusedFn, unfocusedFn, ignore)
  local runFn = function(fnToRun)
    local activeApp = hs.window.focusedWindow():application():name()
    local is_listed = hs.fnutils.contains(appNames, activeApp)
    if (ignore and not is_listed) or (not ignore and is_listed) then
      if fnToRun then fnToRun() end
    end
  end

  module.globalfilter
  :subscribe(hs.window.filter.windowFocused, function() runFn(focusedFn) end)
  :subscribe(hs.window.filter.windowUnfocused, function() runFn(unfocusedFn) end)
end

return module
