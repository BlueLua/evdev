---@meta evdev.selector

---
---Selector for polling and reading from multiple devices.
---
---@class evdev.Selector
---@field _devices evdev.Device[]
local Selector = {}

---
---Add a device to this selector.
---
---```lua
---local Device = evdev.device.open
---local Selector = evdev.selector.new
---
---local kb1 = assert(Device("/dev/input/event5"))
---local kb2 = assert(Device("/dev/input/event10"))
---local sel = Selector({ kb1 })
---
---sel:add(kb2)
---```
---
---@param device evdev.Device
---@return self
function Selector:add(device) end

---
---Remove a device from this selector.
---
---```lua
---local Device = evdev.device.open
---local Selector = evdev.selector.new
---
---local kb1 = assert(Device("/dev/input/event5"))
---local kb2 = assert(Device("/dev/input/event10"))
---local sel = Selector({ kb1, kb2 })
---
---sel:remove(kb2)
---```
---
---@param device evdev.Device
---@return self
function Selector:remove(device) end

---
---Remove all devices from this selector.
---
---```lua
---local Device = evdev.device.open
---local Selector = evdev.selector.new
---
---local kb1 = assert(Device("/dev/input/event5"))
---local kb2 = assert(Device("/dev/input/event10"))
---local sel = Selector({ kb1, kb2 })
---
---sel:clear()
---```
---
---@return self
function Selector:clear() end

---
---Wait until at least one registered device has input available.
---
---```lua
---local Device = evdev.device.open
---local Selector = evdev.selector.new
---
---local kb1 = assert(Device("/dev/input/event5"))
---local kb2 = assert(Device("/dev/input/event10"))
---local sel = Selector({ kb1, kb2 })
---
---for _, dev in ipairs(assert(sel:poll())) do
---  print(dev)
---end
---```
---
---@return evdev.Device[]? devs
---@return string? err
---@nodiscard
function Selector:poll() end

---
---Return an iterator that yields events from registered devices.
---
---```lua
---local Device = evdev.device.open
---local Selector = evdev.selector.new
---
---local kb1 = assert(Device("/dev/input/event5"))
---local kb2 = assert(Device("/dev/input/event10"))
---local sel = Selector({ kb1, kb2 })
---
---for dev, e in sel:events() do
---  print(dev.name, e.code, e.value)
---end
---```
---
---@return fun(): evdev.Device?, evdev.event?
---@nodiscard
function Selector:events() end
---@return self

---@class evdev.selector
---@overload fun(devices?:evdev.Device[]):(sel:evdev.Selector)
local M = {}

---
---Create a selector from an optional list of devices.
---
---```lua
---local evdev = require "evdev"
---local Device = evdev.device.open
---local Selector = evdev.selector.new
---
---local kb1 = assert(Device("/dev/input/event5"))
---local kb2 = assert(Device("/dev/input/event10"))
---local sel = Selector({ kb1, kb2 })
---```
---
---@param devices? evdev.Device[]
---@return evdev.Selector
---@nodiscard
function M.new(devices) end

return M
