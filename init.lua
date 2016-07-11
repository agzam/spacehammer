require "preload"

-- Modal activation / deactivation
modal = hs.hotkey.modal.new({"ctrl", "cmd"}, "space")
mainModalText = "w - windows\na - apps"
function modal:entered() alert(mainModalText, 999999 ) end
modal:bind("","escape", function() modal:exit() end)
function modal:exited() hs.alert.closeAll() end

modalW = hs.hotkey.modal.new();
modal:bind("","w", function() modalW:enter() end)

winmanText = "hjkl \t\t\t\t jumping\ncmd + hjkl \t halves\nalt + hjkl \t\t increments\nshift + hjkl \t resize\ng \t\t\t\t\t grid\nm \t\t\t\t maximize\nu \t\t\t\t\t undo"

function modalW:entered() hs.alert.closeAll(); alert(winmanText, 999999) end

modalA = hs.hotkey.modal.new();
modal:bind("","a", function() modalA:enter() end)

appsModalText = "e \t emacs\nb \t chrome\nt \t terminal\ns \t slack"
function modalA:entered() hs.alert.closeAll(); alert(appsModalText, 999999) end

modalW:bind("","escape", function() exitModals() end)

function exitModals()
  modalA:exit(); modalW:exit(); modal:exit()
end

require "window"

-- applications modal
hs.fnutils.each({
    { key = "t", app = "iTerm" },
    { key = "b", app = "Google Chrome" },
    { key = "e", app = "Emacs" },
    { key = "s", app = "Slack" }
                }, function(item)

    local appActivation = function()
      hs.application.launchOrFocus(item.app)

      local app = hs.appfinder.appFromName(item.app)
      if app then
        app:activate()
        app:unhide()
      end
    end

    modalA:bind("", item.key, function() appActivation(); exitModals() end)
end)

hs.alert.show("Config Loaded")


