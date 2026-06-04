---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local evdev = require "evdev"

local UInput = evdev.uinput.create
local normalize = evdev.uinput._normalize ---@diagnostic disable-line: undefined-field
local ecodes = evdev.ecodes
local fmt = string.format

describe("evdev.uinput()", function()
  local ui

  before_each(function()
    ui = nil
  end)

  after_each(function()
    if ui then
      assert(ui:close())
    end
  end)

  describe("validations", function()
    it("rejects a non-table spec", function()
      assert.Error(function()
        _ = normalize("not a table")
      end, "spec: (table expected, got string)")
    end)

    it("rejects missing uinput paths", function()
      local ui, err = UInput({ path = "/dev/evdev-lua-test-missing-uinput" })
      assert.Nil(ui)
      assert.Equal("open /dev/evdev-lua-test-missing-uinput: No such file or directory", err)
    end)

    it("validates name as a string", function()
      assert.Error(function()
        _ = normalize({ name = 42 })
      end, "spec.name: (string expected, got number)")
    end)

    it("validates path as a string", function()
      assert.Error(function()
        _ = normalize({ path = 42 })
      end, "spec.path: (string expected, got number)")
    end)

    it("validates numeric identity fields", function()
      assert.Error(function()
        _ = normalize({ bustype = "usb" })
      end, "spec.bustype: (number expected, got string)")

      assert.Error(function()
        _ = normalize({ vendor = "1209" })
      end, "spec.vendor: (number expected, got string)")

      assert.Error(function()
        _ = normalize({ product = "e7de" })
      end, "spec.product: (number expected, got string)")

      assert.Error(function()
        _ = normalize({ version = "1" })
      end, "spec.version: (number expected, got string)")
    end)

    it("validates keys", function()
      assert.Error(function()
        _ = normalize({ keys = "KEY_A" })
      end, "spec.keys: (table expected, got string)")

      assert.Error(function()
        _ = normalize({ keys = { "KEY_A" } })
      end, "spec.keys[1]: (number expected, got string)")

      assert.Error(function()
        _ = normalize({ keys = { 999 } })
      end, "spec.keys[1]: expected a valid KEY_* or BTN_* code, got 999")
    end)

    it("drops metacodes from keys", function()
      local spec = normalize({ keys = { ecodes.KEY_MAX, ecodes.KEY_A } })
      assert.Same({ ecodes.KEY_A }, spec.keys)
    end)

    it("validates rels", function()
      assert.Error(function()
        _ = normalize({ rels = "REL_X" })
      end, "spec.rels: (table expected, got string)")

      assert.Error(function()
        _ = normalize({ rels = { "REL_X" } })
      end, "spec.rels[1]: (number expected, got string)")

      assert.Error(function()
        _ = normalize({ rels = { 999 } })
      end, "spec.rels[1]: expected a valid REL_* code, got 999")
    end)

    it("drops metacodes from rels", function()
      local spec = normalize({ rels = { ecodes.REL_MAX, ecodes.REL_X } })
      assert.Same({ ecodes.REL_X }, spec.rels)
    end)

    it("validates event_types", function()
      assert.Error(function()
        _ = normalize({ event_types = "EV_KEY" })
      end, "spec.event_types: (table expected, got string)")

      assert.Error(function()
        _ = normalize({ event_types = { "EV_KEY" } })
      end, "spec.event_types[1]: (number expected, got string)")

      assert.Error(function()
        _ = normalize({ event_types = { 999 } })
      end, "spec.event_types[1]: expected a valid EV_* code, got 999")
    end)

    it("drops metacodes from event_types", function()
      local spec = normalize({ event_types = { ecodes.EV_MAX, ecodes.EV_KEY } })
      assert.Same({ ecodes.EV_KEY }, spec.event_types)
    end)
  end)

  describe("defaults", function()
    it("fills keys, rels, and event types when spec is nil", function()
      local spec = normalize()
      assert.Table(spec.keys)
      assert.Table(spec.rels)
      assert.True(#spec.keys > 0)
      assert.True(#spec.rels > 0)
      assert.Same({ ecodes.EV_SYN, ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_REP }, spec.event_types)
    end)

    it("derives event types for relative pointer devices", function()
      local spec = normalize({ keys = { ecodes.BTN_LEFT }, rels = { ecodes.REL_X, ecodes.REL_Y } })
      assert.Same({ ecodes.EV_SYN, ecodes.EV_KEY, ecodes.EV_REL }, spec.event_types)
      assert.Same({ ecodes.BTN_LEFT }, spec.keys)
      assert.Same({ ecodes.REL_X, ecodes.REL_Y }, spec.rels)
    end)

    it("derives repeat support for keyboard keys", function()
      local spec = normalize({ keys = { ecodes.KEY_A } })
      assert.Same({ ecodes.EV_SYN, ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_REP }, spec.event_types)
    end)

    it("defaults keys when only rels are provided", function()
      local spec = normalize({ rels = { ecodes.REL_X } })
      assert.Table(spec.keys)
      assert.True(#spec.keys > 0)
      assert.Same({ ecodes.REL_X }, spec.rels)
      assert.Same({ ecodes.EV_SYN, ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_REP }, spec.event_types)
    end)

    it("defaults rels when only keys are provided", function()
      local spec = normalize({ keys = { ecodes.KEY_A } })
      assert.Same({ ecodes.KEY_A }, spec.keys)
      assert.Table(spec.rels)
      assert.True(#spec.rels > 0)
      assert.Same({ ecodes.EV_SYN, ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_REP }, spec.event_types)
    end)

    it("keeps explicit event_types unchanged", function()
      local spec = normalize({
        keys = { ecodes.KEY_A },
        rels = { ecodes.REL_X },
        event_types = { ecodes.EV_SYN, ecodes.EV_REL },
      })
      assert.Same({ ecodes.EV_SYN, ecodes.EV_REL }, spec.event_types)
    end)

    it("does not mutate the caller spec table", function()
      local input = {
        keys = { ecodes.KEY_MAX, ecodes.KEY_A },
        rels = { ecodes.REL_MAX, ecodes.REL_X },
        event_types = { ecodes.EV_MAX, ecodes.EV_SYN },
      }
      local spec = normalize(input)
      assert.Not.Equal(input, spec)
      assert.Same({ ecodes.KEY_MAX, ecodes.KEY_A }, input.keys)
      assert.Same({ ecodes.REL_MAX, ecodes.REL_X }, input.rels)
      assert.Same({ ecodes.EV_MAX, ecodes.EV_SYN }, input.event_types)
      assert.Same({ ecodes.KEY_A }, spec.keys)
      assert.Same({ ecodes.REL_X }, spec.rels)
      assert.Same({ ecodes.EV_SYN }, spec.event_types)
    end)

    it("keeps empty capability lists when they are provided", function()
      local spec = normalize({ keys = {}, rels = {} })
      assert.Same({}, spec.keys)
      assert.Same({}, spec.rels)
      assert.Same({ ecodes.EV_SYN }, spec.event_types)
    end)
  end)

  describe("UInput object", function()
    it("loads metadata fields", function()
      local name = "Lua Virtual Device"
      ui = assert(UInput({ name = name }))
      assert.Match("^/dev/input/event%d+$", ui.path)
      assert.Equal(name, ui.name)
    end)

    it("reports open state and closes cleanly", function()
      ui = assert(UInput())
      assert.True(ui:is_open())
      assert.True(ui:close())
      assert.False(ui:is_open())
    end)

    describe("fd()", function()
      it("returns the file descriptor", function()
        ui = assert(UInput())
        local fd = ui:fd()
        assert.Number(fd)
        assert.True(fd >= 0)
      end)

      it("returns nil after close", function()
        ui = assert(UInput())
        assert.True(ui:close())
        assert.Nil(ui:fd())
      end)
    end)

    it("returns a closed-device error for emit after close", function()
      ui = assert(UInput())
      assert.True(ui:close())

      local ok, err = ui:emit(ecodes.EV_KEY, ecodes.KEY_A, 1)
      assert.Nil(ok)
      assert.Equal("uinput device is closed", err)
    end)

    it("returns a closed-device error for sync after close", function()
      ui = assert(UInput())
      assert.True(ui:close())

      local ok, err = ui:sync()
      assert.Nil(ok)
      assert.Equal("uinput device is closed", err)
    end)

    it("returns repeat settings for repeat-capable devices", function()
      ui = assert(UInput())
      local delay, period, err = ui:get_repeat()
      assert.Number(delay)
      assert.Number(period)
      assert.Nil(err)
    end)

    it("updates repeat settings for repeat-capable devices", function()
      ui = assert(UInput())
      local delay, period, err = ui:get_repeat()
      assert.Number(delay)
      assert.Number(period)
      assert.Nil(err)
      assert.True(ui:set_repeat(delay, period))
    end)

    it("returns an unsupported get_repeat error for non-repeat devices", function()
      ui = assert(UInput({
        name = "uinput unsupported get repeat test",
        keys = { ecodes.BTN_LEFT },
        rels = { ecodes.REL_X },
      }))

      local delay, period, err = ui:get_repeat()
      assert.Nil(delay)
      assert.Nil(period)
      assert.Equal(fmt("get repeat %s: device does not support repeat settings", ui.path), err)
    end)

    it("returns an unsupported set_repeat error for non-repeat devices", function()
      ui = assert(UInput({
        name = "uinput unsupported set repeat test",
        keys = { ecodes.BTN_RIGHT },
        rels = { ecodes.REL_Y },
      }))

      local ok, err = ui:set_repeat(300, 40)
      assert.Nil(ok)
      assert.Equal(fmt("set repeat %s: device does not support repeat settings", ui.path), err)
      assert.True(ui:close())
    end)

    it("returns a closed-device error for get_repeat after close", function()
      ui = assert(UInput({ name = "closed get repeat test" }))
      assert.True(ui:close())

      local delay, period, err = ui:get_repeat()
      assert.Nil(delay)
      assert.Nil(period)
      assert.Equal("uinput device is closed", err)
    end)

    it("returns a closed-device error for set_repeat after close", function()
      ui = assert(UInput({ name = "closed set repeat test" }))
      assert.True(ui:close())

      local ok, err = ui:set_repeat(300, 40)
      assert.Nil(ok)
      assert.Equal("uinput device is closed", err)
    end)

    it("validates emit argument types before using the handle", function()
      ui = assert(UInput({ name = "emit validation test" }))

      assert.Error(function()
        ui:emit("key", ecodes.KEY_A, 1)
      end, "type: (number expected, got string)")

      assert.Error(function()
        ui:emit(ecodes.EV_KEY, "a", 1)
      end, "code: (number expected, got string)")

      assert.Error(function()
        ui:emit(ecodes.EV_KEY, ecodes.KEY_A, "down")
      end, "value: (number expected, got string)")
    end)

    it("validates set_repeat argument types before using the handle", function()
      ui = assert(UInput({ name = "set repeat validation test" }))

      assert.Error(function()
        ui:set_repeat("fast", 40)
      end, "delay: (number expected, got string)")

      assert.Error(function()
        ui:set_repeat(300, "slow")
      end, "period: (number expected, got string)")
    end)
  end)
end)
