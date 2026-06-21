local evdev = require "evdev"

local Selector = evdev.selector.new
local Device = evdev.device.open

describe("evdev.selector", function()
  describe("new()", function()
    it("creates selectors and manages devices", function()
      local first = assert(Device("/dev/null"))
      local second = assert(Device("/dev/null"))
      local sel = Selector({ first })

      assert.Table(sel)

      assert(first:close())
      assert(second:close())
    end)

    it("errors on invalid device lists", function()
      assert.Error(function()
        Selector(false) ---@diagnostic disable-line
      end, "devices: (table expected, got boolean)")

      assert.Error(function()
        Selector({ {} }) ---@diagnostic disable-line
      end, "devices[1]: (evdev.Device expected)")
    end)
  end)

  describe("add()", function()
    it("errors on non-device values", function()
      local sel = Selector()

      assert.Error(function()
        sel:add(false) ---@diagnostic disable-line
      end, "device: (evdev.Device expected)")

      assert.Error(function()
        sel:add({}) ---@diagnostic disable-line
      end, "device: (evdev.Device expected)")
    end)

    it("ignores devices that are already registered", function()
      local dev = assert(Device("/dev/null"))
      local sel = Selector()

      sel:add(dev):add(dev)

      local ready = assert(sel:poll())
      assert.Same({ dev }, ready)

      dev:close()
    end)
  end)

  describe("remove()", function()
    it("errors on non-device values", function()
      local sel = Selector()

      assert.Error(function()
        sel:remove(false) ---@diagnostic disable-line
      end, "device: (evdev.Device expected)")

      assert.Error(function()
        sel:remove({}) ---@diagnostic disable-line
      end, "device: (evdev.Device expected)")
    end)

    it("removes a registered device", function()
      local first = assert(Device("/dev/null"))
      local second = assert(Device("/dev/null"))
      local sel = Selector({ first, second })
      sel:remove(first)

      local ready = assert(sel:poll())
      assert.Same({ second }, ready)
      first:close()
      second:close()
    end)
  end)

  describe("clear()", function()
    it("removes all registered devices", function()
      local first = assert(Device("/dev/null"))
      local second = assert(Device("/dev/null"))
      local sel = Selector({ first, second })
      sel:clear()
      first:close()
      second:close()
    end)
  end)

  describe("poll()", function()
    it("returns registered devices that are ready", function()
      local first = assert(Device("/dev/null"))
      local second = assert(Device("/dev/null"))
      local sel = evdev.selector({ first, second })
      local ready, err = sel:poll()

      assert.Nil(err)
      assert.Same({ first, second }, ready)

      first:close()
      second:close()
    end)

    it("returns an error when no devices are registered", function()
      local ready, err = Selector():poll()
      assert.Nil(ready)
      assert.Equal("devices must not be empty", err)
    end)

    it("returns an error when a registered device is closed", function()
      local dev = assert(Device("/dev/null"))
      local sel = evdev.selector({ dev })

      dev:close()

      local ready, err = sel:poll()
      assert.Nil(ready)
      assert.Equal("devices[1]: device is closed", err)
    end)
  end)

  describe("events()", function()
    it("yields events from registered devices", function()
      local first = assert(Device("/dev/null"))
      local second = assert(Device("/dev/null"))
      local sel = Selector({ first, second })
      local polled = false
      local second_sent = false

      function sel:poll()
        if not polled then
          polled = true
          return { second, first }
        end
        return { first }
      end

      function first:read()
        if polled then
          polled = false
          return {
            device = self,
            type = evdev.ecodes.EV_KEY,
            code = evdev.ecodes.KEY_F24,
            value = 1,
          }
        end
      end

      function second:read()
        if second_sent then
          return nil
        end
        second_sent = true
        return {
          device = self,
          type = evdev.ecodes.EV_KEY,
          code = evdev.ecodes.KEY_F23,
          value = 0,
        }
      end

      local events = sel:events()
      local dev1, event1 = assert(events())
      local dev2, event2 = assert(events())

      first:close()
      second:close()

      assert.Equal(second, dev1)
      assert.Equal(evdev.ecodes.KEY_F23, event1.code)
      assert.Equal(first, dev2)
      assert.Equal(evdev.ecodes.KEY_F24, event2.code)
    end)

    it("skips ready devices that return no event", function()
      local first = assert(Device("/dev/null"))
      local second = assert(Device("/dev/null"))
      local sel = Selector({ first, second })

      function sel:poll()
        return { first, second }
      end

      function first:read() end

      function second:read()
        return {
          device = self,
          type = evdev.ecodes.EV_KEY,
          code = evdev.ecodes.KEY_F24,
          value = 1,
        }
      end

      local dev, event = assert(sel:events()())

      first:close()
      second:close()

      assert.Equal(second, dev)
      assert.Equal(evdev.ecodes.KEY_F24, event.code)
    end)

    it("raises poll errors", function()
      local dev = assert(Device("/dev/null"))
      local sel = Selector({ dev })

      function sel:poll()
        return nil, "poll failed"
      end

      assert.Error(function()
        sel:events()()
      end, "poll failed")

      dev:close()
    end)

    it("raises read errors", function()
      local dev = assert(Device("/dev/null"))
      local sel = Selector({ dev })

      function sel:poll()
        return { dev }
      end

      function dev:read()
        return nil, "read failed"
      end

      assert.Error(function()
        sel:events()()
      end, "read failed")

      dev:close()
    end)
  end)
end)
