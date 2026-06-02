---@meta evdev.devices

---
---Input device discovery helpers.
---
---```lua
---local devices = assert(evdev.devices.list_devices())
---print(#devices)
---```
---
---@class evdev.devices
local M = {}

---
---List evdev input devices under `/dev/input`.
---
---```lua
---local devs = assert(evdev.devices.list_devices())
---for _, dev in ipairs(devs) do
---  print(dev.path, dev.name)
---end
---```
---
---@return evdev.deviceInfo[]? devs
---@return string? err
---@nodiscard
function M.list_devices() end

---
---Read metadata for one input device by path.
---
---```lua
---local dev = assert(evdev.devices.device_info("/dev/input/event3"))
---print(dev.name)
---```
---
---@param path evdev.path
---@return evdev.deviceInfo? info
---@return string? err
---@nodiscard
function M.device_info(path) end

---
---Return the first discovered input device matching a path or a device name.
---
---```lua
---local find = evdev.devices.find
---
---local by_event_path = find("/dev/input/event3")
---local by_path_alias = find("/dev/input/by-path/platform-i8042-serio-0-event-kbd")
---local by_id_alias   = find("/dev/input/by-id/usb-Example-event-kbd")
---local by_name       = find("AT Translated Set 2 keyboard")
---
---print(by_event_path and by_event_path.name)
---print(by_path_alias and by_path_alias.path)
---print(by_id_alias   and by_id_alias.path)
---print(by_name       and by_name.path)
---```
---
---@param query string Exact device path, by-id path, by-path path, or device name.
---@return evdev.deviceInfo? dev
---@return string? err
---@nodiscard
function M.find(query) end

---
---Return all discovered input devices matching a path, alias, or device name.
---
---```lua
---local find_all = evdev.devices.find_all
---
---local by_event_path = assert(find_all("/dev/input/event3"))
---local by_path_alias = assert(find_all("/dev/input/by-path/platform-i8042-serio-0-event-kbd"))
---local by_id_alias   = assert(find_all("/dev/input/by-id/usb-Example-event-kbd"))
---local by_name       = assert(find_all("AT Translated Set 2 keyboard"))
---
---print(#by_event_path)
---print(#by_path_alias)
---print(#by_id_alias)
---print(#by_name)
---```
---
---@param query string Exact device path, by-id path, by-path path, or device name.
---@return evdev.deviceInfo[]? devs
---@return string? err
---@nodiscard
function M.find_all(query) end

return M
