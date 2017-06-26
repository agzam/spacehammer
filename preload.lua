-- The default duration for animations, in seconds. Initial value is 0.2; set to 0 to disable animations.
hs.window.animationDuration = 0.2

-- auto reload config
configFileWatcher =
  hs.pathwatcher.new(hs.configdir, function(files)
                       local isLuaFileChange = utils.some(files, function(p)
                                                            return utils.contains(utils.split(p, "%p"), "lua")
                       end)
                       if isLuaFileChange then
                         hs.reload()
                       end
  end):start()

-- persist console history across launches
hs.shutdownCallback = function() hs.settings.set('history', hs.console.getHistory()) end
hs.console.setHistory(hs.settings.get('history'))

-- ensure CLI installed
hs.ipc.cliInstall()

-- helpful aliases
i = hs.inspect
fw = hs.window.focusedWindow
fmt = string.format
bind = hs.hotkey.bind
alert = hs.alert.show
clear = hs.console.clearConsole
reload = hs.reload
pbcopy = hs.pasteboard.setContents
std = hs.stdlib and require("hs.stdlib")
utils = hs.fnutils
hyper = {'⌘', '⌃'}
