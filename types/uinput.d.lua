---@meta evdev.uinput

---
---Configuration used to create a `/dev/uinput` virtual device.
---
---@class evdev.uinputSpec
---@field name? string Device name shown by the kernel (default: `"Lua evdev virtual keyboard"`).
---@field path? string uinput control node (default: `"/dev/uinput"`). Kernel assigns `/dev/input/eventX`.
---@field keys? (evdev.ecodes.key|evdev.ecodes.btn)[] Keys/buttons to expose. Defaults to all real `KEY_*` and `BTN_*` codes when omitted.
---@field rels? evdev.ecodes.rel[] Relative axes to expose. Defaults to all real `REL_*` codes when omitted.
---@field event_types? evdev.ecodes.ev[] Event types to enable. Defaults to `EV_SYN`, plus `EV_KEY`/`EV_REP` for keyboard keys and `EV_REL` for relative axes.
---@field bustype? integer Linux bus type (default: `BUS_USB` / 3).
---@field vendor? integer Vendor ID (default: `0x1209`).
---@field product? integer Product ID (default: `0xE7DE`).
---@field version? integer Version number (default: `1`).

---@class evdev.uinput
local M = {}

---
---Create a virtual input device.
---
---```lua
---local UInput = evdev.uinput.create
---local ui = assert(UInput())
---
----- Give the system a moment to notice the new virtual device.
----- Replace this with your preferred sleep helper.
---os.execute("sleep 0.5")
---
---ui:emit(evdev.ecodes.EV_KEY, evdev.ecodes.KEY_A, 1)
---ui:emit(evdev.ecodes.EV_KEY, evdev.ecodes.KEY_A, 0)
---ui:sync()
---
---print(ui.path)
---```
---
---@param spec? evdev.uinputSpec Virtual device configuration.
---@return evdev.UInput? dev Open virtual device.
---@return string? err Error message on failure.
---@nodiscard
function M.create(spec) end

---
---Open virtual input device handle.
---
---@class evdev.coreUInput
---@field close fun(self: evdev.coreUInput): (ok:true?, err:string?)
---@field emit fun(self: evdev.coreUInput, type:evdev.ecodes.ev, code:integer, value:evdev.eventValue): (ok:true?, err:string?)
---@field info fun(self: evdev.coreUInput): (info:evdev.deviceInfo?, err:string?)
---@field is_open fun(self: evdev.coreUInput): boolean
---@field sync fun(self: evdev.coreUInput): (ok:true?, err:string?)

---
---Open virtual input device handle.
---
---@class evdev.UInput:evdev.deviceInfo
---@field __index fun(dev:self, k:string):any
---@field _core? evdev.coreUInput
---@field _metadata? evdev.deviceInfo
local UInput = {}

---
---Destroy and close the virtual device.
---
---```lua
---local UInput = evdev.uinput.create
---local ui = assert(UInput())
---ui:close()
---```
---
---@return boolean ok `true` when the virtual device closes successfully.
---@return string? err Error message on failure.
function UInput:close() end

---
---Return whether the virtual device is still open.
---
---```lua
---local UInput = evdev.uinput.create
---local ui = assert(UInput())
---
---if ui:is_open() then
---  ui:close()
---end
---```
---
---@return boolean is_open `true` when the virtual device is still open.
---@nodiscard
function UInput:is_open() end

---
---Emit one raw input event.
---
---```lua
---local UInput = evdev.uinput.create
---local ui = assert(UInput())
---
----- Give the system a moment to notice the new virtual device.
----- Replace this with your preferred sleep helper.
---os.execute("sleep 0.5")
---
---local EV_KEY = evdev.ecodes.EV_KEY
---ui:emit(EV_KEY, evdev.ecodes.KEY_A, 1)
---ui:emit(EV_KEY, evdev.ecodes.KEY_A, 0)
---ui:sync()
---
---local EV_REL = evdev.ecodes.EV_REL
---ui:emit(EV_REL, evdev.ecodes.REL_X, 20)
---ui:emit(EV_REL, evdev.ecodes.REL_Y, 10)
---ui:sync()
---```
---
---@param type evdev.ecodes.ev Event type to emit.
---@param code evdev.ecodes.key|evdev.ecodes.btn|evdev.ecodes.rel Event code within the selected type.
---@param value evdev.eventValue Event value to send.
---@return true? ok `true` when the event is emitted successfully.
---@return string? err Error message on failure.
function UInput:emit(type, code, value) end

---
---Emit a `SYN_REPORT` event.
---
---Flush queued input events as one frame.
---
---```lua
---local UInput = evdev.uinput.create
---local ui = assert(UInput())
---
---ui:emit(evdev.ecodes.EV_KEY, evdev.ecodes.KEY_LEFTSHIFT, 0)
---ui:sync()
---```
---
---@return true? ok `true` when `SYN_REPORT` is emitted successfully.
---@return string? err Error message on failure.
function UInput:sync() end

return M
