local utils = require "utils"

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
    utils.keymap(k, 'alt', v, nil)
    utils.keymap(k, 'alt+shift', v, 'alt')
    utils.keymap(k, 'alt+shift+ctrl', v, 'shift')
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
    utils.keymap(k, 'cmd', v, 'cmd+shift')
  end
end
local disableSimpleTabSwitching = function()
  for k, v in pairs(left_right) do
    hs.hotkey.disableAll({'cmd'}, k);
  end
end
local tabSwitchIn = {'Google Chrome', 'iTerm2'}
-- -- enables simple tab switching in listed apps, and ignores keybinding in others - Cmd-h/l can have different meaning in other apps
utils.applyAppSpecific(tabSwitchIn, enableSimpleTabSwithing, nil, nil)
utils.applyAppSpecific(tabSwitchIn, disableSimpleTabSwitching, nil, true)

--- setting conflicting Cmd+L (jump to address bar) keybinding to Cmd+Shift+L
utils.applyAppSpecific({'Google Chrome'},
  function()
    hs.hotkey.bind({'cmd', 'shift'}, 'l', function()
        local app = hs.window.focusedWindow():application()
        app:selectMenuItem({'File', 'Open Location…'})
    end)
  end, nil, nil)

-- ----------------------------
-- App switcher with Cmd++j/k
-- ----------------------------
switcher = hs.window.switcher.new(utils.globalfilter(),
                                  {textSize = 12,
                                   showTitles = false,
                                   showThumbnails = false,
                                   showSelectedTitle = false,
                                   selectedThumbnailSize = 640,
                                   backgroundColor = {0, 0, 0, 0}})

hs.hotkey.bind({'cmd'},'j', function() switcher:next() end)
hs.hotkey.bind({'cmd'},'k', function() switcher:previous() end)

function getChromeMenus()
  local app = hs.window.filter.new{'Google Chrome'}:getWindows()[1]:application()
  local mn =  app:findMenuItem({'File', 'Open Location…'})
  return app:selectMenuItem({'File', 'Open Location…'})
end
