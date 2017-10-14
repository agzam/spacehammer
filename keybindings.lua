local module = {}
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

local simpleViModeKeymaps = simpleViModeKeymaps or {}

local enableSimpleViMode = function()
  for k, v in pairs(arrows) do
      if not simpleViModeKeymaps[k] then
        simpleViModeKeymaps[k] = {}
        table.insert(simpleViModeKeymaps[k], utils.keymap(k, 'alt', v, nil))
        table.insert(simpleViModeKeymaps[k], utils.keymap(k, 'alt+shift', v, 'alt'))
        table.insert(simpleViModeKeymaps[k], utils.keymap(k, 'alt+shift+ctrl', v, 'shift'))
      end
  end
  for _, ks in pairs(simpleViModeKeymaps) do
    for _, k in pairs(ks) do
      k:enable()
    end
  end
end

local disableSimpleViMode = function()
  for _,ks in pairs(simpleViModeKeymaps) do
    for _,km in pairs(ks) do
      km:disable()
    end
  end
end

-- ----------------------------
-- App switcher with Cmd++j/k
-- ----------------------------
switcher = hs.window.switcher.new(utils.globalFilter(),
                                  {textSize = 12,
                                   showTitles = false,
                                   showThumbnails = false,
                                   showSelectedTitle = false,
                                   selectedThumbnailSize = 640,
                                   backgroundColor = {0, 0, 0, 0}})

hs.hotkey.bind({'cmd'},'j', function() switcher:next() end)
hs.hotkey.bind({'cmd'},'k', function() switcher:previous() end)

-- ----------------------------
-- tab switching with Cmd++h/l
-- ----------------------------
local simpleTabSwitching = {}
for dir, key in pairs({ h = "[", l = "]"}) do
  local tf = function()
    hs.eventtap.keyStroke({"shift", "cmd"}, key)
  end
  simpleTabSwitching[dir] = hs.hotkey.new({"cmd"}, dir, tf, nil, tf)
end
-- ------------------
-- App specific keybindings
-- ------------------
module.appSpecificKeys = module.appSpecificKeys or {}

-- Given an app name and hs.hotkey, binds that hotkey when app activates
module.activateAppKey = function(app, hotkey)
  if not module.appSpecificKeys[app] then
    module.appSpecificKeys[app] = {}
  end
  for a, keys in pairs(module.appSpecificKeys) do
    if (a == app or app == "*") and not keys[hotkey.idx] then
      keys[hotkey.idx] = hotkey
    end
    for idx, hk in pairs(keys) do
      if idx == hotkey.idx then
        hk:enable()
      end
    end
  end
end

-- Disables specific hotkeys for a given app name
module.deactivateAppKeys = function(app)
  for a, keys in pairs(module.appSpecificKeys) do
    if a == app then
      for _,hk in pairs(keys) do
        hk:disable()
      end
    end
  end
end

module.appSpecific = {
  ["*"] = {
    activated = function()
      enableSimpleViMode()
    end
  },
  ["Emacs"] = {
    activated = function()
      disableSimpleViMode()
    end
  },
  ["Google Chrome"] = {
    activated = function()
      --- setting conflicting Cmd+L (jump to address bar) keybinding to Cmd+Shift+L
      local cmdSL = hs.hotkey.new({'cmd', 'shift'}, 'l', function()
          local app = hs.window.focusedWindow():application()
          app:selectMenuItem({"File", "Open Location…"})
      end)
      module.activateAppKey("Google Chrome", cmdSL)

      for k, hk in pairs(simpleTabSwitching) do
        module.activateAppKey("Google Chrome", hs.fnutils.copy(hk))
      end
    end,
    deactivated = function() module.deactivateAppKeys("Google Chrome") end,
  },
  ["iTerm2"] = {
    activated = function()
      for k, hk in pairs(simpleTabSwitching) do
        module.activateAppKey("iTerm2", hs.fnutils.copy(hk))
      end
    end,
    deactivated = function() module.deactivateAppKeys("iTerm2") end,
  }
}

-- Creates a new watcher and runs all the functions for specific `appName` and `events`
-- listed in the module in `module.appSpecific`
module.watcher = module.watcher or
  hs.application.watcher.new(
    function(appName, event, appObj)
      -- first executing all fns in `appSpecific["*"]`
      for k,v in pairs (hs.application.watcher) do
        if v == event and module.appSpecific["*"][k] then
          module.appSpecific["*"][k]()
        end
      end
      for app, modes in pairs(module.appSpecific) do
        if app == appName then
          -- terminated is the same as deactivated, right?
          if event == hs.application.watcher["terminated"] and modes["deactivated"] then
            modes["deactivated"]()
          end
          for mode, fn in pairs(modes) do
            if event == hs.application.watcher[mode] then fn() end
          end
        end
      end
  end)

module.watcher:start()

return module
