local windows = {}
local utils = require "utils"

hs.grid.setMargins({0, 0})
hs.grid.setGrid("2x2")
-- hs.window.setFrameCorrectness = true

-- undo for window operations
undo = {}

-- define window movement/resize operation mappings
local arrowMap = {
  k = { half = { 0, 0, 1,.5}, movement = { 0,-20}, complement = "h", resize = "Shorter" },
  j = { half = { 0,.5, 1,.5}, movement = { 0, 20}, complement = "l", resize = "Taller" },
  h = { half = { 0, 0,.5, 1}, movement = {-20, 0}, complement = "j", resize = "Thinner" },
  l = { half = {.5, 0,.5, 1}, movement = { 20, 0}, complement = "k", resize = "Wider" },
}

-- compose screen quadrants from halves
local function quadrant(t1, t2)
  return {t1[1] + t2[1], t1[2] + t2[2], .5, .5}
end

-- move and/or resize windows
local function rect(rect)
  return function()
    undo:push()
    local win = fw()
    if win then win:move(rect) end
  end
end

local function windowJump(modal, fsm, arrow)
  local dir = { h = "West", j = "South", k = "North", l = "East"}
  modal:bind({"ctrl"}, arrow, function()
      slf = fw().filter.defaultCurrentSpace
      local fn = slf["focusWindow"..dir[arrow]]
      fn(slf, nil, true, true)
      windows.highlighActiveWin()
      fsm:toIdle()
  end)
end

local function jumpToLastWindow(fsm)
  utils.globalFilter():getWindows(hs.window.filter.sortByFocusedLast)[2]:focus()
  fsm:toIdle()
end

local function maximizeWindowFrame()
  undo:push()
  fw():maximize(0)
  windows.highlighActiveWin()
end

local function resizeWindow(modal, arrow)
  local dir = { h = "Left", j = "Down", k = "Up", l = "Right"}
  -- screen halves
  modal:bind({}, arrow, function()
      undo:push()
      rect(arrowMap[arrow].half)()
  end)
  -- local thinShort = { h = , }
  -- incrementally
  modal:bind({"alt"}, arrow, function()
      undo:push()
      if arrow == "h" or arrow == "l" then
        hs.grid.resizeWindowThinner(fw())
      end
      if arrow == "j" or arrow == "k" then
        hs.grid.resizeWindowShorter(fw())
      end
      hs.grid['pushWindow'..dir[arrow]](fw())
  end)

  modal:bind({"shift"}, arrow, function()
      undo:push()
      hs.grid['resizeWindow'..arrowMap[arrow].resize](fw())
  end)
end

local function showGrid(fsm)
  local gridSize = hs.grid.getGrid()
  undo:push()
  hs.grid.show(function() hs.grid.setGrid(gridSize) end)
  fsm:toIdle()
end

windows.bind = function(modal, fsm)
  -- maximize window
  modal:bind("","m", maximizeWindowFrame)
  -- undo
  modal:bind("", "u", function() undo:pop() end)
  -- moving/re-sizing windows
  hs.fnutils.each({"h", "l", "k", "j"}, hs.fnutils.partial(resizeWindow, modal))
  -- window grid
  modal:bind("", "g", hs.fnutils.partial(showGrid, fsm))
  -- jumping between windows
  hs.fnutils.each({"h", "l", "k", "j"}, hs.fnutils.partial(windowJump, modal, fsm))
  -- quick jump to the last window
  modal:bind({}, 'w', hs.fnutils.partial(jumpToLastWindow, fsm))
  -- moving windows between monitors
  modal:bind({}, 'p', function() undo:push(); fw():moveOneScreenNorth() end)
  modal:bind({}, 'n', function() undo:push(); fw():moveOneScreenSouth() end)
end

function undo:push()
  local win = fw()
  if win and not undo[win:id()] then
    self[win:id()] = win:frame()
  end
end

function undo:pop()
  local win = fw()
  if win and self[win:id()] then
    win:setFrame(self[win:id()])
    self[win:id()] = nil
  end
end

-- in a short burst highlights the outer border of active window frame
windows.highlighActiveWin = function()
  local rctgl = hs.drawing.rectangle(fw():frame())
  rctgl:setStrokeColor({["red"]=1,  ["blue"]=0, ["green"]=1, ["alpha"]=1})
  rctgl:setStrokeWidth(5)
  rctgl:setFill(false)
  rctgl:show()
  hs.timer.doAfter(0.3, function() rctgl:delete() end)
end

-- activates app by a given appName
windows.activateApp = function(appName)
  hs.application.launchOrFocus(appName)

  local app = hs.application.find(appName)
  if app then
    app:activate()
    hs.timer.doAfter(0.1, windows.highlighActiveWin)
    app:unhide()
  end
end

windows.setMouseCursorAtApp = function(appTitle)
  local sf = hs.application.find(appTitle):focusedWindow():frame()
  local desired_point = hs.geometry.point(sf._x + sf._w - (sf._w * 0.10), sf._y + sf._h - (sf._h * 0.10))
  hs.mouse.setAbsolutePosition(desired_point)
end

return windows
