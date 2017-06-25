local vim = {}

vim.bind = function(modal, fsm)

  local left = function() hs.eventtap.keyStroke({}, "Left") end
  modal:bind({}, 'h', left, nil, left)

  local right = function() hs.eventtap.keyStroke({}, "Right") end
  modal:bind({}, 'l', right, nil, right)

  local up = function() hs.eventtap.keyStroke({}, "Up") end
  modal:bind({}, 'k', up, nil, up)

  local down = function() hs.eventtap.keyStroke({}, "Down") end
  modal:bind({}, 'j', down, nil, down)

end

return vim
