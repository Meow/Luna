
local function patch_str(str, start, endpos, replacement)
	return (start > 1 and str:sub(1, start - 1) or "")..replacement..str:sub(endpos + 1, str:len())
end

packager = packager or { version = "1.0.0" }
local excludes = {}
local packager_search_path = "GAME"

function find_else_or_end(str, pos, opnd)
  local open = opnd or 1
  local sc = false

  for i = (pos or 1), str:len() do
    -- first check for opener
    local opnr = str:sub(i, i + 1) -- if, do
    local opnr2 = str:sub(i, i + 7) -- function
    local opnr3 = str:sub(i, i + 3) -- else

    -- elseif
    if (opnr == "if" and str:sub(i - 1, i - 1) == "e") then continue end

    if ((opnr == "if" or opnr == "do") and str[i + 2]:match("%W")) or opnr2 == "function" then
      open = open + 1
    elseif (str:sub(i, i + 2) == "end") then -- then check for closure
      open = open - 1
    end

    -- found the end of the current block, bail!
    if (opnr3 == "else" and str:sub(i + 4, i + 4) != "i" and open == 1) then
      return i, i + 3, "else"
    end

    -- we've found the closure for the current block, bail out!
    if (open == 0) then return i, i + 2, "end" end
  end

  return -1
end

local function path_to_str(path)
  if (DEBUG) then
    return path:gsub("/", "__"):gsub("%.", "_")
  else
    return 'f'..util.CRC(path)
  end
end

local function generate_function_body(contents, path, file_name, exec_self)
  local path_str = path_to_str(path_to_str(path).."/"..file_name)

  contents = contents:gsub("include%(([^%)\n]+)%)", "include('"..path_to_str(path).."', %1)")
  contents = contents:gsub("[%s\n]AddCSLuaFile%([^%)\n]+%)", "\n")
  contents = contents:gsub("\r\n", "\n")
  contents = contents:gsub("﻿", "")

  return [[
local function _]]..path_str..[[(...)
]]..contents..[[
end
]]..(DEBUG and '__packed_files' or '_fpk')..[[["]]..path_str..[["] = _]]..path_str..[[

]]..(exec_self and '_' + path_str + '()' or '')..[[
]]
end

local function resolve_server(packed, realm)
  local s, e = packed:find("if%s-%(?%s-sv%s-%)?%s-then")

  while (s) do
    local ending, real_ending, what = find_else_or_end(packed, e, 1)

    if (ending != -1) then
      if (what == "else") then
        packed = patch_str(packed, ending, real_ending, "\nif (cl) then\n")

        if (realm == "cl") then
          packed = patch_str(packed, s, ending, "\n")
        else
          packed = patch_str(packed, s, e, "\n")
        end
      else
        if (realm == "cl") then
          packed = patch_str(packed, s, real_ending, "\n")
        else
          packed = patch_str(packed, ending, real_ending, "\n")
          packed = patch_str(packed, s, e, "\n")
        end
      end
    else
      return packed
    end

    s, e = packed:find("if%s-%(?%s-sv%s-%)?%s-then")
  end

  return packed
end

local function resolve_client(packed, realm)
  local s, e = packed:find("if%s-%(?%s-cl%s-%)?%s-then")

  while (s) do
    local ending, real_ending, what = find_else_or_end(packed, e, 1)

    if (ending != -1) then
      if (what == "else") then
        packed = patch_str(packed, ending, real_ending, "\nif (sv) then\n")

        if (realm == "sv") then
          packed = patch_str(packed, s, ending, "\n")
        else
          packed = patch_str(packed, s, e, "\n")
        end
      else
        if (realm == "sv") then
          packed = patch_str(packed, s, real_ending, "\n")
        else
          packed = patch_str(packed, ending, real_ending, "\n")
          packed = patch_str(packed, s, e, "\n")
        end
      end
    else
      break
    end

    s, e = packed:find("if%s-%(?%s-cl%s-%)?%s-then")
  end

  return packed
end

local function resolve_all(packed, realm)
  -- Realm resolution
  packed = resolve_server(packed, realm)
  packed = resolve_client(packed, realm)

  -- Resolve server one more time, as client resolution might have made more if (SERVER) blocks!
  packed = resolve_server(packed, realm)

  return packed
end

function packager.exclude(file)
  excludes[file] = true
end

function packager.set_search_path(path)
  packager_search_path = path or "GAME"
end

function packager.pack(folder, exec_file, realm, packed, recursive)
  if (original_call) then
    packed = nil
  end

  folder = folder:trim("/")

  local exec_self = folder:ends("/lib")

  local original_call = !packed
  realm = realm or "sv"
  packed = packed or (DEBUG and [[
/* PACKAGER v]] + packager.version + [[ */
local __packed_files = {}
local pf="]]..LUNA_APP_FOLDER..[["
__old_include = include
local function _fixp(a)
  if !a:ends('.lun') and !a:ends('.lua') then
    return a + '.lun'
  else
    return a
  end
end
local function include(path, file_name, ...)
  file_name = _fixp(file_name)
  file_name = file_name:gsub("/", "__"):gsub("%.", "_")
  if __packed_files[path.."__"..file_name] then
    return __packed_files[path.."__"..file_name](...)
  elseif __packed_files[file_name] then
    return __packed_files[file_name](...)
  else
    return __old_include(file_name, ...)
  end
end
local function import(a, ...)
  local b = pf+_fixp(a)
  b = b:gsub("/", "__"):gsub("%.", "_")
  if __packed_files[b] then
    return __packed_files[b](...)
  else
    error('Failed to import file \''+a+'\' (file not found)')
  end
end
/* END PACKAGER DEFAULT CODE */
]] or [[local _fpk = {}
local pf="]]..LUNA_APP_FOLDER..[["
_olin = include
local function _fixp(a)
  if !a:ends('.lun') and !a:ends('.lua') then
    return a + '.lun'
  else
    return a
  end
end
local function include(a, b, ...)
  local fp = 'f'..util.CRC(a.."/".._fixp(b))
  local fpb = 'f'..util.CRC(b)
  if _fpk[fp] then
    return _fpk[fp](...)
  elseif _fpk[fpb] then
    return _fpk[fpb](...)
  else
    return _olin(b, ...)
  end
end
local function import(a, ...)
  local b = 'f'..util.CRC(pf+_fixp(a))
  if _fpk[b] then
    return _fpk[b](...)
  else
    error('Failed to import file \''+a+' :'+b+':\' (file not found)')
  end
end
]])

  local files, dirs = file.Find(folder.."/*", packager_search_path)

  for k, v in ipairs(files) do
    if realm == "sv" and (v:StartWith("cl_") or v:find("client")) then continue end
    if realm == "cl" and (v:StartWith("sv_") or v == "init.lua" or v:find("server")) then continue end

    local ext = v:GetExtensionFromFilename()

    if ext == "lua" or ext == "lun" then
      local full_path = folder.."/"..v

      if !excludes[full_path] then
        local contents = file.Read(full_path, packager_search_path)
        contents = hook.Run("Lua_Preprocess", contents, full_path, folder.."/")

        packed = packed..generate_function_body(contents, folder, v, exec_self)
      end
    end
  end

  if (recursive != false) then
    for k, v in ipairs(dirs) do
      if !excludes[folder.."/"..v] and !excludes[folder.."/"..v.."/"] then
        packed = packager.pack(folder.."/"..v, nil, realm, packed)
      end
    end
  end

  if (exec_file) then
    local folder_part = string.GetPathFromFilename(exec_file) or ''
    local file_part = string.GetFileFromFilename(exec_file) or ''

    packed = packed.."\n_"..path_to_str(path_to_str((folder.."/"..folder_part):trim("/")).."/"..file_part).."()\n"
  end

  if (original_call) then
    -- Realm resolution
    packed = resolve_all(packed, realm)
    
    if (!DEBUG) then
      --packed = luna.minifier:Minify(packed, false)
    end
  end

  return packed
end

--local pak = luna.minifier:Minify(packager.pack("gamemodes/flux", "gamemode/init.lua", "cl"))
--file.Write("test_packager.txt", pak)

--print(util.RelativePathToFull("luna_packager.lua"))
