---@meta evdev._core

---
---Resolved symlink entry from `/dev/input/by-id` or `/dev/input/by-path`.
---
---@class evdev.deviceAlias
---@field path string
---@field target string

---@class evdev._core
local M = {}

---List readable event nodes from a device directory.
---@return evdev.deviceInfo[]? devs
---@return string? err
---@nodiscard
function M.list_devices() end

---Read kernel metadata for one device node.
---@param path evdev.path
---@return evdev.deviceInfo? info
---@return string? err
---@nodiscard
function M.device_info(path) end

---Open a raw device userdata.
---@param path evdev.path
---@return evdev.Device? dev
---@return string? err
---@nodiscard
function M.open_device(path) end

---Block until one or more raw device handles are readable.
---@param devs evdev.Device[]
---@return integer[]? ready_indexes
---@return string? err
---@nodiscard
function M.poll_devices(devs) end

---Create a raw uinput userdata.
---@param spec evdev.uinputSpec
---@return evdev.coreUInput? ui
---@return string? err
---@nodiscard
function M.create_uinput(spec) end

---List symlinks in an alias directory.
---@param dir evdev.path
---@return evdev.deviceAlias[]? aliases
---@return string? err
---@nodiscard
function M.list_aliases(dir) end

return M
