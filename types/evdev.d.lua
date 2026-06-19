---@meta evdev

---@alias evdev.fd integer Linux file descriptor number.
---@alias evdev.path string Path to an evdev device node or related input path.
---@alias evdev.eventValue integer Numeric value attached to an input event.

local version = "evdev 0.2.0" -- x-release-please-version

---
---Lua bindings for Linux evdev devices and /dev/uinput virtual devices.
---
---@class evdev
---@field _core evdev._core
---@field device evdev.device
---@field devices evdev.devices
---@field ecodes evdev.ecodes
---@field events evdev.events
---@field selector evdev.selector
---@field uinput evdev.uinput
return {
  _VERSION = version,
  _util = {}, ---@module "evdev._util"
}
