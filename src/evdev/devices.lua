local evdev = require "evdev"

local core = evdev._core
local util = evdev._util

local validate = util.validate
local list_aliases = core.list_aliases
local list_devices = core.list_devices

---@type evdev.devices
local M = {
  device_info = core.device_info,
}

---@type fun(devs:evdev.deviceInfo[], paths:table<string,evdev.deviceInfo>, field:"id_aliases"|"path_aliases")
local function attach_alias(devs, paths, field)
  local dir = "/dev/input/" .. (field == "path_aliases" and "by-path" or "by-id")
  local aliases = list_aliases(dir)
  if not aliases then
    return
  end

  for _, alias in ipairs(aliases) do
    local info = paths[alias.target]
    if info then
      local v = info[field]
      if not v then
        v = {}
        info[field] = v
      end
      v[#v + 1] = alias.path
    end
  end

  for _, info in ipairs(devs) do
    if info[field] then
      table.sort(info[field])
    end
  end
end

---@param devs evdev.deviceInfo[]
local function attach_aliases(devs)
  local paths = {}
  for _, info in ipairs(devs) do
    paths[info.path] = info
  end

  attach_alias(devs, paths, "id_aliases")
  attach_alias(devs, paths, "path_aliases")
end

local function has_value(ls, query)
  if ls then
    for _, v in ipairs(ls) do
      if v == query then
        return true
      end
    end
  end
  return false
end

---@param dev evdev.deviceInfo
local function matches_query(dev, query, is_path)
  if is_path then
    return dev.path == query or has_value(dev.id_aliases, query) or has_value(dev.path_aliases, query)
  end
  return dev.name == query
end

function M.list_devices()
  local devs, err = list_devices()
  if not devs then
    return nil, err
  end

  attach_aliases(devs)

  table.sort(devs, function(a, b)
    return (a.path or "") < (b.path or "")
  end)

  return devs
end

function M.find(query)
  validate("query", query, "string")
  local matches, err = M.find_all(query)
  if not matches then
    return nil, err
  end
  return matches[1]
end

function M.find_all(query)
  validate("query", query, "string")

  local devs, err = M.list_devices()
  if not devs then
    return nil, err
  end

  local matches = {}
  local is_path = query:sub(1, 11) == "/dev/input/"
  for _, dev in ipairs(devs) do
    if matches_query(dev, query, is_path) then
      matches[#matches + 1] = dev
    end
  end
  return matches
end

return M
