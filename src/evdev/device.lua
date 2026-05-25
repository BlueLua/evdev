---@diagnostic disable: inject-field

local evdev = require "evdev"

local open_device = evdev._core.open_device
local validate = evdev._util.validate

---@type evdev.Device
local Device = {}
Device.__index = Device

---@type fun(dev:evdev.Device, fname:string, ...):...
local function call_device(dev, fname, ...)
  local core = dev._core
  if not core then
    return nil, "device is closed"
  end
  return core[fname](core, ...)
end

function Device:read()
  local event, err = call_device(self, "read")
  if event then
    event.device = self
  end
  return event, err
end

function Device:close()
  if self._core then
    local ok, err = self._core:close()
    if not ok then
      return nil, err
    end
    self._core = nil
  end
  return true
end

function Device:events()
  local poll = self.poll
  local read = self.read
  return function()
    local ready, poll_err = poll(self)
    if not ready then
      error(poll_err, 2)
    end

    local event, read_err = read(self)
    if not event then
      error(read_err, 2)
    end
    return event
  end
end

function Device:get_repeat()
  local delay, period = call_device(self, "get_repeat")
  if delay == nil then
    return nil, nil, period
  end
  return delay, period
end

-- stylua: ignore start
function Device:is_open()        return self._core ~= nil and self._core:is_open() end
function Device:set_repeat(d, p) return call_device(self, "set_repeat", d, p)      end
function Device:ungrab()         return call_device(self, "ungrab")                end
function Device:grab()           return call_device(self, "grab")                  end
function Device:info()           return call_device(self, "info")                  end
function Device:fd()             return call_device(self, "fd")                    end
function Device:poll()           return call_device(self, "poll")                  end
function Device:flush()          return call_device(self, "flush")                 end
-- stylua: ignore end

---@type evdev.device
local M = {}

function M.open(path)
  validate("path", path, "string")
  local dev, err = open_device(path)
  if not dev then
    return nil, err
  end
  return setmetatable({ _core = dev }, Device)
end

return M
