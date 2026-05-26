local evdev = require "evdev"

local ecodes = evdev.ecodes
local events = evdev.events

describe("events", function()
  it("exposes key event value constants", function()
    assert.is_table(events)
    assert.Equal(0, events.RELEASE)
    assert.Equal(1, events.PRESS)
    assert.Equal(2, events.REPEAT)
  end)

  it("is_release() identifies key releases", function()
    local release = { type = ecodes.EV_KEY, value = events.RELEASE }
    local press = { type = ecodes.EV_KEY, value = events.PRESS }

    assert.True(events.is_release(release))
    assert.False(events.is_release(press))
  end)

  it("is_press() identifies key presses", function()
    local press = { type = ecodes.EV_KEY, value = events.PRESS }
    local rel = { type = ecodes.EV_REL, value = events.PRESS }

    assert.True(events.is_press(press))
    assert.False(events.is_press(rel))
  end)

  it("is_repeat() identifies key repeats", function()
    local repeat_event = { type = ecodes.EV_KEY, value = events.REPEAT }
    local press = { type = ecodes.EV_KEY, value = events.PRESS }

    assert.True(events.is_repeat(repeat_event))
    assert.False(events.is_repeat(press))
  end)

  it("is_key() identifies EV_KEY events", function()
    assert.True(events.is_key({ type = ecodes.EV_KEY, code = 123, value = 99 }))
    assert.False(events.is_key({ type = ecodes.EV_REL, code = 456, value = -3 }))
  end)

  it("is_rel() identifies EV_REL events", function()
    assert.True(events.is_rel({ type = ecodes.EV_REL, code = 77, value = 12 }))
    assert.False(events.is_rel({ type = ecodes.EV_ABS, code = 88, value = 34 }))
  end)

  it("is_abs() identifies EV_ABS events", function()
    assert.True(events.is_abs({ type = ecodes.EV_ABS, code = 11, value = 222 }))
    assert.False(events.is_abs({ type = ecodes.EV_SYN, code = 0, value = 0 }))
  end)

  it("is_syn() identifies EV_SYN events", function()
    assert.True(events.is_syn({ type = ecodes.EV_SYN, code = 0, value = 0 }))
    assert.False(events.is_syn({ type = ecodes.EV_KEY, code = 30, value = 1 }))
  end)
end)
