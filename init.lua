require "preload"
local machine = require "statemachine"
local windows = require "windows"
local slack = require "slack"

local displayModalText = function(txt)
  hs.alert.closeAll()
  alert(txt, 999999)
end

modals = {
  main = {
    init = function(self, fsm) 
      self.modal = hs.hotkey.modal.new({"cmd"}, "space")
      self.modal:bind("","w", nil, function() fsm:toWindows() end)
      self.modal:bind("","a", nil, function() fsm:toApps() end)
      self.modal:bind("","escape", function() fsm:toMain() end)
      function self.modal:entered() displayModalText "w - windows\na - apps" end
    end 
  },
  windows = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText "cmd + hjkl \t jumping\nhjkl \t\t\t\t halves\nalt + hjkl \t\t increments\nshift + hjkl \t resize\nn, p \t next, prev screen\ng \t\t\t\t\t grid\nm \t\t\t\t maximize\nu \t\t\t\t\t undo"
      self.modal:bind('','h', function() alert('h pressed while in windows modal') end)
      windows.bind(self.modal, fsm)
      self.modal:enter()
    end
  },
  apps = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText "e \t emacs\nc \t chrome\nt \t terminal\ns \t slack\nb \t brave"
      hs.fnutils.each({
          { key = "t", app = "iTerm" },
          { key = "c", app = "Google Chrome" },
          { key = "b", app = "Brave" },
          { key = "e", app = "Emacs" },
          { key = "g", app = "Gitter" }}, function(item)

          local appActivation = function()
            hs.application.launchOrFocus(item.app)

            local app = hs.application.find(item.app)
            if app then
              app:activate()
              hs.timer.doAfter(0.1, windows.highlighActiveWin)
              app:unhide()
            end
          end

          self.modal:bind("", item.key, function() appActivation(); fsm:toMain()  end)
      end)

      slack.bind(self.modal, fsm)

      self.modal:enter()
    end,
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

local fsm = machine.create({
    initial = 'main',
    events = {
      { name = 'toMain',    from = '*', to = 'main' },
      { name = 'toWindows', from = 'main', to = 'windows' },
      { name = 'toApps',    from = 'main', to = 'apps' }
    },
    callbacks = {
      onmain = function(self, event, from, to)
        exitAllModals()
        initModal(to, self)
        hs.alert.closeAll()
      end,
      onwindows = function(self, event, from, to) initModal(to, self) end,
      onapps = function(self, event, from, to) initModal(to, self) end
    }
})

fsm:toMain()

hs.alert.show("Config Loaded")


