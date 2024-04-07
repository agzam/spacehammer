local function file_exists_3f(filepath)
  local file = io.open(filepath, "r")
  if file then
    io.close(file)
  else
  end
  return (file ~= nil)
end
local script_path = hs.spoons.scriptPath()
local paths_file = hs.spoons.resourcePath("paths.lua")
local function butlast(tbl)
  local total = (#tbl - 1)
  local new_tbl = {}
  for i = 1, total, 1 do
    table.insert(new_tbl, tbl[i])
    new_tbl = new_tbl
  end
  return new_tbl
end
local function dirname(filepath)
  local _2_
  do
    local state = {paths = {}, path = ""}
    for i = 1, #filepath, 1 do
      local char = filepath:sub(i, i)
      if (char == "/") then
        table.insert(state.paths, state.path)
        do end (state)["path"] = ""
      else
        state["path"] = (state.path .. char)
      end
      state = state
    end
    _2_ = state
  end
  return table.concat(butlast(_2_.paths), "/")
end
if (not _G["fennel-installed"] and not file_exists_3f(paths_file)) then
  local file = io.open(paths_file, "w")
  local homedir = os.getenv("HOME")
  local customdir = (homedir .. "/.spacehammer")
  file:write("return {\n", ("  homedir = '" .. homedir .. "',\n"), ("  customdir = '" .. customdir .. "',\n"), ("  fennel = '" .. script_path .. "vendor/fennel.lua" .. "'\n"), "};\n")
  file:flush()
  file:close()
else
end
local paths = dofile(paths_file)
local fennel = dofile(paths.fennel)
if not _G["fennel-installed"] then
  local src_path = dirname(script_path)
  print(package.path)
  do end (package)["path"] = (src_path .. "/?.lua;" .. src_path .. "/?/init.lua;" .. package.path)
  do end (fennel)["path"] = (src_path .. "/?.fnl;" .. src_path .. "/?/init.fnl;" .. fennel.path)
  do end (fennel)["macro-path"] = (src_path .. "/?.fnl;" .. src_path .. "/?/init-macros.fnl;" .. fennel["macro-path"])
  fennel.install()
  _G["fennel-installed"] = true
else
end
return {fennel = fennel, paths = paths}
