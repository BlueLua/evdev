---@meta evdev

---@alias evdev.fd integer Linux file descriptor number.
---@alias evdev.path string Path to an evdev device node or related input path.
---@alias evdev.eventValue integer Numeric value attached to an input event.

---
---Lua bindings for Linux evdev devices and /dev/uinput virtual devices.
---
---@class evdev
---@field _VERSION "evdev 0.1.0"
---@field _core evdev._core
---@field device evdev.device
---@field devices evdev.devices
---@field ecodes evdev.ecodes
---@field selector evdev.selector
---@field uinput evdev.uinput
return {
  _util = {}, ---@module "evdev._util"
}
