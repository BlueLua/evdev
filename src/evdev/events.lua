local evdev = require "evdev"

local EV_KEY = evdev.ecodes.EV_KEY
local EV_REL = evdev.ecodes.EV_REL
local EV_ABS = evdev.ecodes.EV_ABS
local EV_SYN = evdev.ecodes.EV_SYN
local RELEASE = 0
local PRESS = 1
local REPEAT = 2

---@type evdev.events
local M = {
  RELEASE = RELEASE,
  PRESS = PRESS,
  REPEAT = REPEAT,
}

function M.is_release(e)
  return e.type == EV_KEY and e.value == RELEASE
end

function M.is_press(e)
  return e.type == EV_KEY and e.value == PRESS
end

function M.is_repeat(e)
  return e.type == EV_KEY and e.value == REPEAT
end

function M.is_key(e)
  return e.type == EV_KEY
end

function M.is_rel(e)
  return e.type == EV_REL
end

function M.is_abs(e)
  return e.type == EV_ABS
end

function M.is_syn(e)
  return e.type == EV_SYN
end

return M
