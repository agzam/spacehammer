local multimedia = {}

multimedia.musicApp = "Google Play Music Desktop Player"

multimedia.mKey = function (key)
  return function()
    hs.eventtap.event.newSystemKeyEvent(string.upper(key), true):post()
    hs.timer.usleep(5)
    hs.eventtap.event.newSystemKeyEvent(string.upper(key), false):post()
  end
end

local bind = function(hotkeyModal, fsm)
  hotkeyModal:bind("", "a", function()
               hs.application.launchOrFocus(multimedia.musicApp)
               fsm:toIdle()
  end)
  hotkeyModal:bind("", "h", function() multimedia.mKey("previous")(); fsm:toIdle() end)
  hotkeyModal:bind("", "l", function() multimedia.mKey("next")(); fsm:toIdle() end)
  local sUp = multimedia.mKey("sound_up")
  hotkeyModal:bind("", "k", sUp, nil, sUp)
  local sDn = multimedia.mKey("sound_down")
  hotkeyModal:bind("", "j", sDn, nil, sDn)
  local pl = function() multimedia.mKey("play")(); fsm:toIdle() end
  hotkeyModal:bind("", "s", pl)
end

multimedia.addState = function(modal)
  modal.addState("media", {
                   init = function(self, fsm)
                     self.hotkeyModal = hs.hotkey.modal.new()
                     modal.displayModalText "h \t previous track\nl \t next track\nk \t volume up\nj \t volume down\ns \t play/pause\na \t launch player"

                     self.hotkeyModal:bind("","escape", function() fsm:toIdle() end)
                     self.hotkeyModal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)

                     bind(self.hotkeyModal, fsm)
                     self.hotkeyModal:enter()
  end})
end

return multimedia
