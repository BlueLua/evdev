---@meta evdev.device

---
---One Linux input event returned by `Device:read()`.
---
---@class evdev.event
---@field device? evdev.Device
---@field type evdev.ecodes.ev
---@field code integer
---@field value evdev.eventValue
---@field sec? integer
---@field usec? integer

---
---Input device metadata.
---
---@class evdev.deviceInfo
---@field bustype integer Bus type from the kernel input ID.
---@field id_aliases? string[] Symlink aliases under `/dev/input/by-id`, when available.
---@field path_aliases? string[] Symlink aliases under `/dev/input/by-path`, when available.
---@field name? string Device name reported by the kernel.
---@field path string Device node path.
---@field phys? string Physical device path, when available.
---@field product integer Product ID from the kernel input ID.
---@field uniq? string Unique identifier string, when available.
---@field vendor integer Vendor ID from the kernel input ID.
---@field version integer Hardware version from the kernel input ID.

---
---Open and manage input devices.
---
---@class evdev.coreDevice
---@field close fun(self: evdev.coreDevice): (ok:true?, err:string?)
---@field fd fun(self: evdev.coreDevice): (fd:evdev.fd?, err:string?)
---@field flush fun(self: evdev.coreDevice): (count:integer?, err:string?)
---@field get_repeat fun(self: evdev.coreDevice): (delay:integer?, period:integer?, err:string?)
---@field grab fun(self: evdev.coreDevice): (ok:true?, err:string?)
---@field is_open fun(self: evdev.coreDevice): boolean
---@field poll fun(self: evdev.coreDevice): (ready:boolean?, err:string?)
---@field read fun(self: evdev.coreDevice): (event:evdev.event?, err:string?)
---@field set_repeat fun(self: evdev.coreDevice, delay:integer, period:integer): (ok:true?, err:string?)
---@field ungrab fun(self: evdev.coreDevice): (ok:true?, err:string?)

---@class evdev.Device:evdev.deviceInfo
---@field __index fun(dev:self, k:string):any
---@field _core? evdev.coreDevice
---@field _metadata? evdev.deviceInfo
local Device = {}

---
---Close the device.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
---print(dev:is_open()) --> true
---dev:close()
---print(dev:is_open()) --> false
---```
---
---@return boolean ok `true` when the device closes successfully.
---@return string? err Error message on failure.
function Device:close() end

---
---Return whether this device handle still has an open file descriptor.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
---if dev:is_open()
---  then dev:close()
---end
---```
---
---@return boolean isOpen `true` when the device is still open.
---@nodiscard
function Device:is_open() end

---Return the current auto-repeat delay and period in milliseconds.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
---local delay, period, err = dev:get_repeat()
---assert(delay, err)
---print(delay, period)
---```
---
---@return integer? delay Initial delay before repeating (milliseconds).
---@return integer? period Interval between repeats (milliseconds).
---@return string? err Error message on failure.
function Device:get_repeat() end

---
---Set the auto-repeat delay and period in milliseconds.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
---local delay, period, err = dev:get_repeat()
---assert(delay, err)
---print(delay, period)
---
---assert(dev:set_repeat(300, 40))
---print(dev:get_repeat())
---```
---
---@param delay integer Initial delay before repeating (milliseconds).
---@param period integer Interval between repeats (milliseconds).
---@return true? ok `true` when the repeat settings are updated successfully.
---@return string? err Error message on failure.
function Device:set_repeat(delay, period) end

---
---Return the underlying Linux file descriptor.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
---local fd = dev:fd()
---print(fd)
---```
---
---@return evdev.fd? fd Linux file descriptor.
---@nodiscard
function Device:fd() end

---
---Take exclusive control of the input device.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---assert(dev:grab())
---```
---
---@return true? ok `true` when the device is grabbed successfully.
---@return string? err Error message on failure.
function Device:grab() end

---
---Release exclusive control of the input device.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---assert(dev:grab())
---assert(dev:ungrab())
---```
---
---@return true? ok `true` when the grab is released successfully.
---@return string? err Error message on failure.
function Device:ungrab() end

---
---Wait in the kernel until this device has input available.
---
---This does not spin the CPU. It returns when `read()` can fetch at least one
---queued event.
---
---```lua
---local Device = evdev.device.open
---local ecodes = evdev.ecodes
---
---local dev = assert(Device("/dev/input/eventX"))
---
----- This is the manual form of `dev:events()`.
---while true do
---  if assert(dev:poll()) then
---    local e = assert(dev:read())
---    if e.type == ecodes.EV_KEY then
---      print(e.code, e.value)
---    end
---  end
---end
---```
---
---
---@return boolean? ready `true` when input is ready to read.
---@return string? err Error message on failure.
function Device:poll() end

---
---Return an iterator that waits for and yields input events one by one.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
---for e in dev:events() do
---  if e.type == ecodes.EV_KEY then
---    print(e.code, e.value)
---  end
---end
---```
---
---@return fun(): evdev.event?
function Device:events() end

---
---Read one input event. Returns `nil` when no event is queued.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
----- This is the manual form of `dev:events()`.
---while true do
---  if assert(dev:poll()) then
---    local e = assert(dev:read())
---    if e.type == ecodes.EV_KEY then
---      print(e.code, e.value)
---    end
---  end
---end
---```
---
---@return evdev.event? event Next queued input event.
---@return string? err Error message on failure.
---@nodiscard
function Device:read() end

---Drain queued events and return how many were discarded.
---
---This is useful after grabbing a device when you want to ignore any stale
---events that were already queued.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---
---assert(dev:grab())
---os.execute("sleep 3")
---
----- Move the mouse or press keys during the sleep.
---
---local dropped = assert(dev:flush())
---print("discarded", dropped, "stale events")
---```
---
---@return integer? count Number of discarded events.
---@return string? err Error message on failure.
function Device:flush() end

---@class evdev.device
local M = {}

---
---Return whether a value is an `evdev.Device` instance.
---
---```lua
---local Device = evdev.device.open
---local is_device = evdev.device.is_device
---
---local dev = assert(Device("/dev/input/eventX"))
---print(is_device(dev)) --> true
---print(is_device({}))  --> false
---```
---
---@param value any
---@return boolean
function M.is_device(value) end

---
---Open an input device by path.
---
---```lua
---local Device = evdev.device.open
---local dev = assert(Device("/dev/input/eventX"))
---```
---
---@param path evdev.path
---@return evdev.Device? dev Open input device.
---@return string? err Error message on failure.
---@nodiscard
function M.open(path) end

return M
