---@diagnostic disable: missing-fields, inject-field

local evdev = require "evdev"

local validate = evdev._util.validate
local tbl_find = evdev._util.tbl_find
local is_device = evdev.device.is_device
local poll_devices = evdev._core.poll_devices

---@type evdev.Selector
local Selector = {}
Selector.__index = Selector

local function validate_device(lbl, dev)
  if not is_device(dev) then
    error(lbl .. ": (evdev.Device expected)", 3)
  end
  return dev
end

---@param devs evdev.Device[]
local function validate_handles(devs)
  for i, dev in ipairs(devs) do
    local core = type(dev) == "table" and rawget(dev, "_core")
    if not core then
      return nil, "devices[" .. i .. "]: device is closed"
    end
  end
  return true
end

function Selector:add(dev)
  validate_device("device", dev)
  if not tbl_find(self._devices, dev) then
    self._devices[#self._devices + 1] = dev
    self._handles[#self._handles + 1] = rawget(dev, "_core")
  end
  return self
end

function Selector:remove(dev)
  validate_device("device", dev)
  local i = tbl_find(self._devices, dev)
  if i then
    table.remove(self._devices, i)
    table.remove(self._handles, i)
  end
  return self
end

function Selector:clear()
  self._devices = {}
  self._handles = {}
  return self
end

function Selector:poll()
  local devs = self._devices
  local ok, err = validate_handles(devs)
  if not ok then
    return nil, err
  end

  local ready_indexes, poll_err = poll_devices(self._handles)
  if not ready_indexes then
    return nil, poll_err
  end

  local ready = {}
  for i, v in ipairs(ready_indexes) do
    ready[i] = devs[v]
  end
  return ready
end

function Selector:events()
  local ready = {}
  local i = 1

  return function()
    while true do
      while i <= #ready do
        local dev = ready[i]
        local event, err = dev:read()
        if event then
          return dev, event
        end
        if err then
          error(err, 2)
        end
        i = i + 1
      end

      local next, err = self:poll()
      if not next then
        error(err, 2)
      end
      ready = next
      i = 1
    end
  end
end

---@type evdev.selector
local M = {}

function M.new(devs)
  validate("devices", devs, "table", true)
  devs = devs or {}
  local handles = {}

  for i, dev in ipairs(devs) do
    validate_device("devices[" .. i .. "]", dev)
    handles[i] = rawget(dev, "_core")
  end

  return setmetatable({ _devices = devs, _handles = handles }, Selector)
end

return setmetatable(M, {
  __call = function(_, devs)
    return M.new(devs)
  end,
})
