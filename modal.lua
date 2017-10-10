local modal = {}
local stateMachine = require "statemachine"
local utils = require "utils"
local windows = require "windows"

-- local log = hs.logger.new('modal-module','debug')

modal.displayModalText = function(txt)
  hs.alert.closeAll()
  alert(txt, 999999)
end

modal.exitAllModals = function()
  hs.fnutils.each(modal.states, function(s)
                    if s.hotkeyModal then s.hotkeyModal:exit() end
  end)
end

modal.addState = function(name,state)
  modal.states[name] = state
end

local filterAllowedApps = function(w)
  local allowedApps = {"Emacs", "iTerm2"}
  if (not w:isStandard()) and (not hs.fnutils.contains(allowedApps, w:application():name())) then
    return false;
  end
  return true;
end

modal.states = {
  idle =  {
    from = "*", to = "idle",
    callback = function(self, event, from, to)
      hs.alert.closeAll()
      modal.exitAllModals()
    end
  },
  main = {
    from = "*", to = "main",
    init = function(self, fsm)
      if self.hotkeyModal then
        self.hotkeyModal:enter()
      else
        self.hotkeyModal = hs.hotkey.modal.new({"cmd"}, "space")
      end
      self.hotkeyModal:bind("","space", nil, function() fsm:toIdle(); windows.activateApp("Alfred 3") end)
      self.hotkeyModal:bind("","w", nil, function() fsm:toWindows() end)
      self.hotkeyModal:bind("","a", nil, function() fsm:toApps() end)
      self.hotkeyModal:bind("", "m", nil, function() fsm:toMedia() end)
      self.hotkeyModal:bind("", "x", nil, function() fsm:toEmacs() end)
      self.hotkeyModal:bind("","j", nil, function()
                        local wns = hs.fnutils.filter(hs.window.allWindows(), filterAllowedApps)
                        hs.hints.windowHints(wns, nil, true)
                        fsm:toIdle() end)
      self.hotkeyModal:bind("","escape", function() fsm:toIdle() end)
      function self.hotkeyModal:entered()
        modal.displayModalText "w \t- windows\na \t- apps\n j \t- jump\nm - media\nx\t- emacs"
      end
    end
  }
}

-- -- each modal has: name, init function
modal.createMachine = function()
  -- build events based on modals
  local events = {}
  local params = function(fsm)
    local callbacks = {}
    for k, s in pairs (modal.states) do
      table.insert(events, { name = "to" .. utils.capitalize(k),
                             from = s.from or {"main", "idle"},
                             to = s.to or k})
      if s.callback then
        cFn = s.callback
      else
        cFn = function(self, event, from, to)
          local st = modal.states[to]
          st.init(st, self)
        end
      end
      callbacks["on" .. k] = cFn
    end

    return callbacks
  end

  return stateMachine.create({ initial = "idle",
                               events = events,
                               callbacks = params(self)})
end

return modal
