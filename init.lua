require "preload"
local keybindings = require "keybindings"
local machine = require "statemachine"
local windows = require "windows"
local slack = require "slack"

require "preview-app"
logger = hs.logger.new('balls')
formatText = function(textMap)
  local longest = 0
  maxKeyCombo = hs.fnutils.each(textMap, function(textmapping)
                                    len = string.len(textmapping['key'])
                                    newLongest = len > longest
                                    if newLongest then
                                      longest = len
                                    end
                                         end
  )
  hs.fnutils.each(textMap, function(textmapping)
                    len = string.len(textmapping['key'])
                    logger:e(len)
                    padding = longest - len

                    i = 0
                    while i < padding do
                      textmapping['key'] = textmapping['key'] .. ' '
                      i = i + 1
                    end
  end)
  local finalText = ''
  hs.fnutils.each(textMap, function(textmapping)
                    finalText = finalText .. textmapping['key'] .. ' → ' .. textmapping['name'] .. '\n'
  end)
  return finalText
end

local displayModalText = function(txt)
  hs.alert.closeAll()
  alert(formatText(txt),
        {
          textFont = "Courier",
          textSize = 26,
          radius = 5,
          fillColor = {
            red = .05,
            green = .12,
            blue = .17,
            alpha = 0.7
          },
          textColor = {
            red = .91,
            green = .88,
            blue = .8
          },
          strokeColor = {
            black = 1,
            alpha = 0.7
          }
        }, 999999)
end

allowedApps = {"Emacs", "iTerm2"}
hs.hints.style = "vimperator"
hs.hints.showTitleThresh = 4
hs.hints.titleMaxSize = 10
hs.hints.fontSize = 30

local filterAllowedApps = function(w)
  if (not w:isStandard()) and (not utils.contains(allowedApps, w:application():name())) then
    return false;
  end
  return true;
end

modals = {
  main = {
    init = function(self, fsm)
      if self.modal then
        self.modal:enter()
      else
        self.modal = hs.hotkey.modal.new({"cmd"}, "space")
      end
      self.modal:bind("","space", nil, function() fsm:toIdle(); windows.activateApp("Alfred 2") end)
      self.modal:bind("","w", nil, function() fsm:toWindows() end)
      self.modal:bind("","a", nil, function() fsm:toApps() end)
      self.modal:bind("","s", nil, function() fsm:toSystem() end)
      self.modal:bind("","j", nil, function()
                        local wns = hs.fnutils.filter(hs.window.allWindows(), filterAllowedApps)
                        hs.hints.windowHints(wns, nil, true)
                        fsm:toIdle() end)
      self.modal:bind("","escape", function() fsm:toIdle() end)
      function self.modal:entered()
        displayModalText({
            {
              key = 'w',
              name = 'windows'
            },
            {
              key = 'a',
              name = 'apps'
            },
            {
              key = 's',
              name = 'system'
            },
            {
              key = 'j',
              name = 'jump'
            }
          })
      end
    end
  },
  windows = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText({
          {
            key = 'cmd + hjkl',
            name = 'jumping'
          },
          {
            key = 'hjkl',
            name = 'halves'
          },
          {
            key = 'alt + hjkl',
            name = 'increments'
          },
          {
            key = 'shift + hjkl',
            name = 'resize'

          },
          {
            key = 'np',
            name = 'next and prev screen'

          },
          {
            key = 'g',
            name = 'grid'

          },
          {
            key = 'm',
            name = 'maximize'

          },
          {
            key = 'u',
            name = 'undo'

          }
      })

      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
      windows.bind(self.modal, fsm)
      self.modal:enter()
    end
  },
  apps = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText({
        {
          key = 'e',
          name = 'emacs'

        },
        {
          key = 'g',
          name = 'chrome'

         },
        {
          key = 'i',
          name = 'iTerm'

        },
        {
          key = 's',
          name = 'slack'

        },
        {
          key = 'b',
          name = 'brave'

        },
        {
          key = 't',
          name = 'telegram'

        },
        {
          key = 'n',
          name = 'notes'

        }
      })
      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
      for key, app in pairs({
          i = "iTerm2",
          g = "Google Chrome",
          b = "Brave",
          e = "Emacs",
          t = "Telegram",
          n = "Notes"
      }) do
        self.modal:bind("", key, function() windows.activateApp(app); fsm:toIdle() end)
      end

      slack.bind(self.modal, fsm)
      self.modal:enter()
    end
  },
  system = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText({
          {
            key = 'l',
            name = 'lockscreen'

          }
      })
      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
      for key, fn in pairs({
          l = function() hs.caffeinate.lockScreen(); fsm:toIdle() end
      }) do
        self.modal:bind("", key, fn)
      end

      slack.bind(self.modal, fsm)
      self.modal:enter()
    end
  }
}

local initModal = function(state, fsm)
  local m = modals[state]
  m.init(m, fsm)
end

exitAllModals = function()
  utils.each(modals, function(m)
               if m.modal then
                 m.modal:exit()
               end
  end)
end


buildTopLevelCallbacks = function(topLevelNames)
  dickhandler = function(self, event, from, to)
    initModal(to, self)
  end

  calldicks = {
    onidle = function(self, event, from, to)
      hs.alert.closeAll()
      exitAllModals()
    end,
    onmain = dickhandler
  };
  hs.fnutils.each(topLevelNames, function(command)
                    calldicks['on' .. command] = dickhandler
  end)
  return calldicks
end

function titleCase( first, rest )
  return first:upper()..rest:lower()
end

buildTopLevelEvents = function(topLevelNames)
  eventdicks = {
    { name = "toIdle", from = "*", to = "idle" },
    { name = "toMain", from = "*", to = "main" },
  }

  hs.fnutils.each(topLevelNames, function(command)
                    if command ~= 'main' then
                      hs.fnutils.concat(eventdicks, {
                                          { name = 'to' .. string.gsub(command, "(%a)([%w_']*)", titleCase), from = { 'main', 'idle' }, to = '' .. command }
                      })
                    end
  end)
  return eventdicks
end

topLevel = { 'windows', 'apps', 'system' }
local fsm = machine.create({
    initial = "idle",
    events = buildTopLevelEvents(topLevel),
    callbacks = buildTopLevelCallbacks(topLevel)
})

fsm:toMain()

hs.alert.show("Config Loaded")
