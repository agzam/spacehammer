local modal = {}
local statemachine = require "statemachine"

modal.fsm = machine.create(nil)

-- each modal has: name, init funtion
local createMachine = function()
  -- build events based on modals
  local events = hs.fnutils.map(modal.modals, function(m)
                                  return { name = "to" .. }
  end)
end

modal.registerModal = function(m)
  table.insert(spacehammer.modals, m)
  for k, m in pairs(modal.modals) do
    initial = ""
  end
end

modal.exitAll = function ()
  utils.each(modal.modals, function(m)
               if m.modal then
                 m.modal:exit()
               end
  end)
end

local initModal = function(state)
  local m = modal.modals[state]
  m.init(m, modal.fsm)
end
