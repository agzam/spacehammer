local utils = require "utils"

local REPEAT_FASTER = 10 * 1000
local REPEAT_SLOWER = 100 * 1000
local NO_REPEAT = -1

local function keyStroke(mod, key, repeatDelay)
    hs.eventtap.event.newKeyEvent(mod, key, true):post()
    if repeatDelay <= 0 then
        repeatDelay = REPEAT_FASTER
    end
    hs.timer.usleep(repeatDelay)
    hs.eventtap.event.newKeyEvent(mod, key, false):post()
end

local function keyStrokeSystem(key, repeatDelay)
    hs.eventtap.event.newSystemKeyEvent(key, true):post()
    if repeatDelay <= 0 then
        repeatDelay = REPEAT_FASTER
    end
    hs.timer.usleep(repeatDelay)
    hs.eventtap.event.newSystemKeyEvent(key, false):post()
end

-- Map sourceKey + sourceMod -> targetKey + targetMod
local function keymap(sourceKey, sourceMod, targetKey, targetMod, repeatDelay)
    sourceMod = sourceMod or {}

    repeatDelay = repeatDelay or REPEAT_FASTER
    noRepeat = repeatDelay <= 0

    local fn = nil
    if targetMod == nil then
        fn = hs.fnutils.partial(keyStrokeSystem, string.upper(targetKey), repeatDelay)
    else
        targetMod = utils.splitStr(targetMod, '+')
        fn = hs.fnutils.partial(keyStroke, targetMod, targetKey, repeatDelay)
    end
    if noRepeat then
        hs.hotkey.bind(sourceMod, sourceKey, fn, nil, nil)
    else
        hs.hotkey.bind(sourceMod, sourceKey, fn, nil, fn)
    end
end

-- ------------------
-- simple vi-mode 
-- ------------------
local arrows = {
  h = 'left',
  j = 'down',
  k = 'up',
  l = 'right'
}
local enableSimpleViMode = function()
  for k, v in pairs(arrows) do
    keymap(k, 'alt', v, '')
    keymap(k, 'alt+shift', v, 'alt')
    keymap(k, 'alt+shift+ctrl', v, 'shift')
  end
end
local disableSimpleViMode = function()
  for k,v in pairs (arrows) do
    hs.hotkey.disableAll({'alt'}, k);
  end
end
utils.applyAppSpecific({'Emacs'}, disableSimpleViMode, nil, false)
utils.applyAppSpecific({'Emacs'}, enableSimpleViMode, nil, true)

-- ----------------------------
-- tab switching with Cmd++h/l 
-- ----------------------------
local left_right = {h = '[', l = ']'}
local enableSimpleTabSwithing = function()
  for k, v in pairs(left_right) do
    keymap(k, 'cmd', v, 'cmd+shift')
  end
end
local disableSimpleTabSwitching = function()
  for k, v in pairs(left_right) do
    hs.hotkey.disableAll({'cmd'}, k);
  end
end
local tabSwitchIn = {'Google Chrome', 'iTerm2'}
-- enables simple tab switching in listed apps, and ignores keybinding in others - Cmd-h/l can have different meaning in other apps 
utils.applyAppSpecific(tabSwitchIn, enableSimpleTabSwithing, nil, nil)
utils.applyAppSpecific(tabSwitchIn, disableSimpleTabSwitching, nil, true)

-- ----------------------------
-- App switcher with Cmd++j/k 
-- ----------------------------
switcher = hs.window.switcher.new(utils.globalfilter, {textSize = 12,
                                                       showTitles = false,
                                                       showThumbnails = false,
                                                       showSelectedTitle = false,
                                                       selectedThumbnailSize = 640,
                                                       backgroundColor = {0, 0, 0, 0}})

hs.hotkey.bind('cmd','j', function() switcher:next() end)
hs.hotkey.bind('cmd','k', function() switcher:previous() end)
