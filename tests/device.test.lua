---@diagnostic disable: need-check-nil

local evdev = require "evdev"
local system = require "system"

local ecodes = evdev.ecodes

local Device = evdev.device.open
local UInput = evdev.uinput.create
local sleep = system.sleep
local fmt = string.format

describe("evdev.device", function()
  local mouse, mouse_path
  local kb, kb_path

  setup(function()
    kb = assert(UInput({ keys = { ecodes.KEY_ENTER, ecodes.KEY_F24, ecodes.KEY_F23 } }))
    mouse = assert(UInput({
      keys = { ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE },
      rels = { ecodes.REL_X, ecodes.REL_Y, ecodes.REL_WHEEL },
    }))

    sleep(0.1)

    mouse_path = assert(mouse:info()).path
    kb_path = assert(kb:info()).path
  end)

  teardown(function()
    if mouse then
      mouse:close()
    end
    if kb then
      kb:close()
    end
  end)

  describe("open()", function()
    it("opens a device by path", function()
      local dev = assert(Device(kb_path))
      assert.True(dev:is_open())
      assert.True(dev:close())
    end)

    it("returns true for device instances", function()
      local dev = assert(Device(kb_path))
      assert.True(evdev.device.is_device(dev))
      assert.False(evdev.device.is_device({}))
      assert.False(evdev.device.is_device(false))
      assert.True(dev:close())
    end)

    it("errors on non-string path", function()
      assert.Error(function()
        Device(1) ---@diagnostic disable-line
      end, "path: (string expected, got number)")
    end)

    it("rejects missing devices", function()
      local dev, err = Device("/dev/input/evdev-lua-test-missing")
      assert.Nil(dev)
      assert.String(err)
    end)
  end)

  describe("close()", function()
    it("closes the device cleanly", function()
      local dev = Device(kb_path)
      assert.True(dev:close())
      assert.False(dev:is_open())
    end)

    it("returns true when called multiple times", function()
      local dev = Device(kb_path)

      assert.True(dev:is_open())
      assert.True(dev:close())
      assert.False(dev:is_open())

      assert.True(dev:close())
      assert.True(dev:close())
      assert.True(dev:close())
      assert.False(dev:is_open())
    end)
  end)

  describe("info()", function()
    it("returns info", function()
      local dev = Device(kb_path)
      local info = dev:info()
      assert.Table(info)
      assert.Equal(kb_path, info.path)
      assert.True(dev:close())
    end)

    it("returns a closed-device error after close", function()
      local dev = Device(kb_path)
      dev:close()

      local info, err = dev:info()
      assert.Nil(info)
      assert.Equal("device is closed", err)
    end)
  end)

  describe("fd()", function()
    it("returns the file descriptor", function()
      local dev = Device(mouse_path)
      local fd = dev:fd()
      assert.Number(fd)
      assert.True(fd >= 0)
      assert.True(dev:close())
    end)

    it("returns nil after close", function()
      local dev = Device(mouse_path)
      assert.True(dev:close())
      assert.Nil(dev:fd())
    end)
  end)

  describe("get_repeat()", function()
    it("returns repeat settings for repeat-capable devices", function()
      local dev = Device(kb_path)
      local delay, period, err = dev:get_repeat()
      assert.Number(delay)
      assert.Number(period)
      assert.Nil(err)
      assert.True(dev:close())
    end)

    it("returns an unsupported error for non-repeat devices", function()
      local dev = Device(mouse_path)
      local delay, period, err = dev:get_repeat()
      assert.Nil(delay)
      assert.Nil(period)
      assert.Equal(fmt("get repeat %s: device does not support repeat settings", mouse_path), err)
      assert.True(dev:close())
    end)
  end)

  describe("set_repeat()", function()
    it("updates repeat settings for repeat-capable devices", function()
      local dev = Device(kb_path)
      local delay, period, err = dev:get_repeat()

      assert.Number(delay)
      assert.Number(period)
      assert.Nil(err)

      ---@cast delay -?
      ---@cast period -?

      assert.True(dev:set_repeat(delay, period))
      assert.True(dev:close())
    end)

    it("returns an unsupported error for non-repeat devices", function()
      local dev = Device(mouse_path)
      local ok, err = dev:set_repeat(300, 40)
      assert.Nil(ok)
      assert.Equal(fmt("set repeat %s: device does not support repeat settings", mouse_path), err)
      assert.True(dev:close())
    end)
  end)

  describe("grab()", function()
    it("grabs the device", function()
      local dev = Device(kb_path)
      assert.True(dev:grab())
      assert.True(dev:close())
    end)

    it("errors when the device is already grabbed", function()
      local dev = Device(kb_path)
      assert.True(dev:grab())
      dev:grab()

      local ok, err = dev:grab()
      assert.Nil(ok)
      assert.Equal(fmt("grab %s: device is already grabbed", kb_path), err)
      assert.True(dev:close())
    end)
  end)

  describe("ungrab() ", function()
    it("releases the device grab", function()
      local dev = Device(kb_path)
      assert.True(dev:grab())
      assert.True(dev:ungrab())
      assert.True(dev:close())
    end)

    it("errors when the device is not grabbed", function()
      local dev = Device(kb_path)
      local ok, err = dev:ungrab()
      assert.Nil(ok)
      assert.Equal(fmt("ungrab %s: device is not grabbed", kb_path), err)
      assert.True(dev:close())
    end)
  end)

  describe("poll()", function()
    it("returns true when input is ready", function()
      local dev = Device(kb_path)
      assert.True(kb:emit(ecodes.EV_KEY, ecodes.KEY_F24, 1))
      assert.True(kb:sync())
      assert.True(dev:poll())
      assert.True(dev:close())
    end)

    it("returns a closed-device error after close", function()
      local dev = Device(kb_path)
      assert.True(dev:close())

      local ready, err = dev:poll()
      assert.Nil(ready)
      assert.Equal("device is closed", err)
    end)
  end)

  describe("flush()", function()
    it("drains queued events", function()
      local dev = Device(kb_path)

      assert.True(kb:emit(ecodes.EV_KEY, ecodes.KEY_F24, 1))
      assert.True(kb:sync())
      assert.True(dev:poll())

      local dropped = assert(dev:flush())
      assert.True(dropped > 0)

      dropped = assert(dev:flush())
      assert.True(dropped == 0)

      local event, err = dev:read()
      assert.Nil(event)
      assert.Nil(err)

      assert.True(dev:close())
    end)

    it("returns a closed-device error after close", function()
      local dev = Device(kb_path)
      assert.True(dev:close())

      local count, err = dev:flush()
      assert.Nil(count)
      assert.Equal("device is closed", err)
    end)
  end)

  describe("read()", function()
    it("returns one emitted event", function()
      local ui = assert(UInput({ keys = { ecodes.KEY_F24 } }))
      sleep(0.1)

      local path = assert(ui:info()).path
      local dev = assert(Device(path))

      assert.True(ui:emit(ecodes.EV_KEY, ecodes.KEY_F24, 1))
      assert.True(ui:sync())

      local ready = assert(dev:poll())
      local event = assert(dev:read())

      assert.True(ready)
      assert.Equal(dev, event.device)
      assert.Equal(ecodes.EV_KEY, event.type)
      assert.Equal(ecodes.KEY_F24, event.code)
      assert.Equal(1, event.value)

      assert.True(dev:close())
      assert.True(ui:close())
    end)

    it("returns nil when no event is queued", function()
      local dev = Device(kb_path)
      local event, err = dev:read()
      assert.Nil(event)
      assert.Nil(err)
      assert.True(dev:close())
    end)

    it("returns a closed-device error after close", function()
      local dev = Device(kb_path)
      assert.True(dev:close())

      local event, err = dev:read()
      assert.Nil(event)
      assert.Equal("device is closed", err)
    end)
  end)

  describe("events()", function()
    local function next_key_event(events)
      while true do
        local event = events()
        assert.Table(event)

        if event.type == ecodes.EV_KEY then
          return event
        end
      end
    end

    it("yields events through an iterator", function()
      local ui = assert(UInput({ keys = { ecodes.KEY_F24 } }))
      sleep(0.1)

      local path = assert(ui:info()).path
      local dev = assert(Device(path))

      assert.True(ui:emit(ecodes.EV_KEY, ecodes.KEY_F24, 1))
      assert.True(ui:sync())

      local event = next_key_event(dev:events())

      assert.Equal(dev, event.device)
      assert.Equal(ecodes.EV_KEY, event.type)
      assert.Equal(ecodes.KEY_F24, event.code)
      assert.Equal(1, event.value)

      assert.True(dev:close())
      assert.True(ui:close())
    end)

    it("yields multiple events in order", function()
      local ui = assert(UInput({ keys = { ecodes.KEY_F24, ecodes.KEY_F23 } }))
      sleep(0.1)

      local dev = assert(Device(assert(ui:info()).path))

      assert.True(ui:emit(ecodes.EV_KEY, ecodes.KEY_F24, 1))
      assert.True(ui:sync())
      assert.True(ui:emit(ecodes.EV_KEY, ecodes.KEY_F23, 1))
      assert.True(ui:sync())

      local events = dev:events()
      local first = next_key_event(events)
      local second = next_key_event(events)

      assert.Equal(dev, first.device)
      assert.Equal(dev, second.device)
      assert.Equal(ecodes.KEY_F24, first.code)
      assert.Equal(ecodes.KEY_F23, second.code)
      assert.Equal(1, first.value)
      assert.Equal(1, second.value)

      assert.True(dev:close())
      assert.True(ui:close())
    end)

    it("raises a closed-device error after close", function()
      local dev = Device(kb_path)
      assert.True(dev:close())
      assert.Error(function()
        dev:events()()
      end, "device is closed")
    end)
  end)
end)
