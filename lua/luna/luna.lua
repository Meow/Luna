luna = luna or {}
luna.pp = luna.pp or {}
luna.util = luna.util or {}

require('luna')

LUNA_VERSION = LUNA_VERSION or '0.0.1'

-- temporary
setenv = setenv or function() end
getenv = getenv or function(k)
  if (k == "LUNA_REALM") then
    return "sv"
  elseif (k == "LUNA_ENV") then
    return "development"
  else
    return ""
  end
end

DEBUG = (getenv("LUNA_ENV") == "development")

function luna.util.FindClosure(str, opener, closer, start, opnd, chk)
  chk = chk or function() return end
  local open = opnd or 0

  for i = (start or 1), str:len() do
    -- first check for opener
    local opnr = str:sub(i, i + opener:len() - 1)

    if (chk(opnr, str, i)) then continue end

    if (str:sub(i, i + opener:len() - 1) == opener) then
      open = open + 1
    elseif (str:sub(i, i + closer:len() - 1) == closer) then -- then check for closure
      open = open - 1
    end

    -- we've found the closure for the current block, bail out!
    if (open == 0) then return i, i + closer:len() - 1 end
  end

  return -1
end

function luna.util.FindLogicClosure(str, pos, opnd)
  local open = opnd or 0

  for i = (pos or 1), str:len() do
    -- first check for opener
    local prev = str:sub(i - 1, i - 1) -- previous letter
    local opnr = str:sub(i, i + 1) -- if, do
    local opnr2 = str:sub(i, i + 7) -- function
    local opnr3 = str:sub(i, i + 8) -- namespace

    -- elseif or part of another word
    if ((!prev:match("([^%w])") and prev != "\n") or (opnr == "if" and str:sub(i - 1, i - 1) == "e")) then continue end

    if (opnr == "if" or opnr == "do" or opnr2 == "function" or opnr3 == "namespace") then
      open = open + 1
    elseif (str:sub(i, i + 2) == "end") then -- then check for closure
      open = open - 1
    end

    -- we've found the closure for the current block, bail out!
    if (open <= 0) then return i, i + 2 end
  end

  return -1
end

function luna.util.FindTableVal(str, tab)
  tab = tab or _G

  local pieces = str:split(".")

  for k, v in ipairs(pieces) do
    if (tab[v] == nil) then
      return false
    else
      tab = tab[v]
    end
  end

  return tab
end

function luna.util.FindTableClosure(str, pos, opnd, custom_opener, custom_closer, where)
  local open = opnd or 0
  local opnr = custom_opener or "{"
  local closr = custom_closer or "}"

  for i = (pos or 1), str:len(), where or 1 do
    local v = str:sub(i, i)

    if (v == opnr) then
      open = open + 1
    elseif (v == closr) then
      open = open - 1
    end

    if (open <= 0) then return i end
  end

  return -1
end

function table.safe_merge(to, from)
	local oldIndex, oldIndex2 = to.__index, from.__index

	to.__index = nil
	from.__index = nil

	table.Merge(to, from)

	to.__index = oldIndex
	from.__index = oldIndex2
end

include("preprocessor.lua")
include("lib/packager.lua")

print("Processing currently active gamemode...")

local gm = engine.ActiveGamemode()
local base = "gamemodes/" + gm + "/"
local app_folder, gm_folder = base + "app/", base + "gamemode/"
local cl_init, init = app_folder + "src/client.lun", app_folder + "src/server.lun"

if (!file.Exists(init, "GAME") or !file.Exists(cl_init, "GAME")) then
  ErrorNoHalt("No Luna sources found for the current gamemode, aborting...")

  return
end

fileio.Write(gm_folder..'init.lua', '-- If you are seeing this, your gamemode likely failed to compile.\nCheck console for details!\n')
fileio.Write(gm_folder..'cl_init.lua', '-- If you are seeing this, your gamemode likely failed to compile.\nCheck console for details!\n')

packager.exclude(gm_folder)
packager.exclude(base.."Packages")
packager.exclude(base..gm..".txt")

LUNA_PROJECT_FOLDER = 'addons/luna/'
LUNA_APP_FOLDER = 'addons/luna/lua/luna/'

production = !DEBUG
development = DEBUG

local support_filename = '.luna/'..LUNA_VERSION..'/base/support.lua'
local lpm_filename = '.luna/'..LUNA_VERSION..'/base/package_manager.lua'

packager.set_search_path("LUA")
fileio.MakeDirectory('lua/.luna/'..LUNA_VERSION..'/base')
fileio.Write('lua/' + support_filename, packager.pack("luna/support/", "support.lun"))
fileio.Write('lua/' + lpm_filename, packager.pack("lpm/", "lpm.lun"))
packager.set_search_path("GAME")

function luna_load()
  if file.Exists(support_filename, "LUA") then
    include(support_filename)
  else
    error("Unable to find Luna support package, something may have gone terribly wrong!\n")
  end

  LUNA_PROJECT_FOLDER = base
  LUNA_APP_FOLDER = app_folder

  local start_time = os.clock()

  fileio.Write(gm_folder + "init.lua", packager.pack(base, 'app/src/server.lun', 'sv'))
  fileio.Write(gm_folder + "cl_init.lua", packager.pack(base, 'app/src/client.lun', 'cl'))

  print("Pre-processed Luna sources!")
  print("Compiled in "..math.round(os.clock() - start_time, 4).." second(s).")
end

luna_load()

concommand.Add("luna_reload", luna_load)
