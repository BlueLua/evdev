---@meta evdev.events

---
---Event value constants and event predicates.
---
---```lua
---local e = {
---  type = evdev.ecodes.EV_KEY,
---  value = evdev.events.RELEASE
---}
---
---print(evdev.events.is_release(e)) --> true
---print(evdev.events.is_press(e))   --> false
---print(evdev.events.is_repeat(e))  --> false
---```
---
---@class evdev.events
---@field RELEASE 0 Key or button release value.
---@field PRESS 1 Key or button press value.
---@field REPEAT 2 Key repeat value.
local M = {}

---
---Return whether an event is a key/button release.
---
---```lua
---local e = { type = evdev.ecodes.EV_KEY, value = evdev.events.RELEASE }
---print(evdev.events.is_release(e)) --> true
---```
---
---@param event evdev.event
---@return boolean
---@nodiscard
function M.is_release(event) end

---
---Return whether an event is a key/button press.
---
---```lua
---local e = { type = evdev.ecodes.EV_KEY, value = evdev.events.PRESS }
---print(evdev.events.is_press(e)) --> true
---```
---
---@param event evdev.event
---@return boolean
---@nodiscard
function M.is_press(event) end

---
---Return whether an event is a key repeat.
---
---```lua
---local e = { type = evdev.ecodes.EV_KEY, value = evdev.events.REPEAT }
---print(evdev.events.is_repeat(e)) --> true
---```
---
---@param event evdev.event
---@return boolean
---@nodiscard
function M.is_repeat(event) end

---
---Return whether an event has type `EV_KEY`.
---
---```lua
---local e = { type = evdev.ecodes.EV_KEY }
---print(evdev.events.is_key(e)) --> true
---```
---
---@param event evdev.event
---@return boolean
---@nodiscard
function M.is_key(event) end

---
---Return whether an event has type `EV_REL`.
---
---```lua
---local e = { type = evdev.ecodes.EV_REL }
---print(evdev.events.is_rel(e)) --> true
---```
---
---@param event evdev.event
---@return boolean
---@nodiscard
function M.is_rel(event) end

---
---Return whether an event has type `EV_ABS`.
---
---```lua
---local e = { type = evdev.ecodes.EV_ABS }
---print(evdev.events.is_abs(e)) --> true
---```
---
---@param event evdev.event
---@return boolean
---@nodiscard
function M.is_abs(event) end

---
---Return whether an event has type `EV_SYN`.
---
---```lua
---local e = { type = evdev.ecodes.EV_SYN }
---print(evdev.events.is_syn(e)) --> true
---```
---
---@param event evdev.event
---@return boolean
---@nodiscard
function M.is_syn(event) end

return M
