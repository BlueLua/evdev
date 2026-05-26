local evdev = require "evdev"
local system = require "system"

local UInput = evdev.uinput.create
local sleep = system.sleep

local function find_by_id(devs)
  for _, dev in ipairs(devs) do
    if dev.id_aliases and next(dev.id_aliases) then
      return dev
    end
  end
end

local function find_by_path(devs)
  for _, dev in ipairs(devs) do
    if dev.path_aliases and next(dev.path_aliases) then
      return dev
    end
  end
end

describe("evdev.devices", function()
  local devs
  local kb1, kb2, mouse

  setup(function()
    devs = assert(evdev.devices.list_devices())
    kb1 = assert(UInput({ name = "evdev test keyboard" }))
    kb2 = assert(UInput({ name = "evdev test keyboard" }))
    mouse = assert(UInput({ name = "evdev test mouse" }))
    sleep(0.1)
  end)

  -- stylua: ignore
  teardown(function()
    if kb1   then   kb1:close() end
    if kb2   then   kb2:close() end
    if mouse then mouse:close() end
  end)

  describe("list_devices() ", function()
    local devs, err = evdev.devices.list_devices()
    assert.Table(devs)
    assert.Nil(err)

    ---@cast devs -?

    it("returns device info tables", function()
      for _, info in ipairs(devs) do
        assert.Table(info)
        assert.String(info.path)
      end
    end)

    it("sorts devices by path", function()
      for i, info in ipairs(devs) do
        if i > 1 then
          assert.True(devs[i - 1].path <= info.path)
        end
      end
    end)

    it("includes created virtual devices", function()
      local seen = {}
      for _, info in ipairs(devs) do
        seen[info.path] = true
      end
      assert.True(seen[kb1.path])
      assert.True(seen[kb2.path])
      assert.True(seen[mouse.path])
    end)

    it("attaches alias lists when present", function()
      for _, info in ipairs(devs) do
        if info.id_aliases then
          assert.Table(info.id_aliases)
          for _, alias in ipairs(info.id_aliases) do
            assert.String(alias)
          end
        end

        if info.path_aliases then
          assert.Table(info.path_aliases)
          for _, alias in ipairs(info.path_aliases) do
            assert.String(alias)
          end
        end
      end
    end)
  end)

  describe("find() ", function()
    local find = evdev.devices.find

    it("returns nil for a missing path", function()
      local dev = find("/dev/input/evdev-lua-test-missing")
      assert.Nil(dev)
    end)

    it("returns nil for a missing name", function()
      local dev = find("evdev-lua-test-missing")
      assert.Nil(dev)
    end)

    it("finds a device by path", function()
      local dev = find(kb1.path)
      assert.Table(dev) ---@cast dev -?
      assert.Equal(kb1.path, dev.path)
    end)

    it("finds a device by name", function()
      local dev = find("evdev test keyboard")
      assert.Table(dev) ---@cast dev -?
      assert.Equal("evdev test keyboard", dev.name)
    end)

    it("finds a device by by-id alias when present", function()
      local dev_with_alias = find_by_id(devs)
      if not dev_with_alias then
        pending("no discovered device with a by-id alias")
      end

      local dev = find(dev_with_alias.id_aliases[1])
      assert.Table(dev) ---@cast dev -?
      assert.Equal(dev_with_alias.path, dev.path)
    end)

    it("finds a device by by-path alias when present", function()
      local dev_with_alias = find_by_path(devs)
      if not dev_with_alias then
        pending("no discovered device with a by-path alias")
      end

      local dev = find(dev_with_alias.path_aliases[1])
      assert.Table(dev) ---@cast dev -?
      assert.Equal(dev_with_alias.path, dev.path)
    end)
  end)

  describe("find_all()", function()
    local find_all = evdev.devices.find_all

    it("returns an empty list for a missing path", function()
      local devs = find_all("/dev/input/evdev-lua-test-missing")
      assert.Table(devs)
      assert.Equal(0, #devs)
    end)

    it("returns an empty list for a missing name", function()
      local devs = find_all("evdev-lua-test-missing")
      assert.Table(devs)
      assert.Equal(0, #devs)
    end)

    it("finds a device by path", function()
      local dev = find_all(kb1.path)
      assert.Table(dev) ---@cast dev -?
      assert.Equal(1, #dev)
      assert.Equal(kb1.path, dev[1].path)
    end)

    it("finds all devices by shared name", function()
      local dev = find_all("evdev test keyboard")
      assert.Table(dev) ---@cast dev -?
      assert.Equal(2, #dev)
      assert.Equal("evdev test keyboard", dev[1].name)
      assert.Equal("evdev test keyboard", dev[2].name)
    end)

    it("finds a device by by-id alias when present", function()
      local dev_with_alias = find_by_id(devs)
      if not dev_with_alias then
        pending("no discovered device with a by-id alias")
      end

      local dev = find_all(dev_with_alias.id_aliases[1])
      assert.Table(dev) ---@cast dev -?
      assert.Equal(1, #dev)
      assert.Equal(dev_with_alias.path, dev[1].path)
    end)

    it("finds a device by by-path alias when present", function()
      local dev_with_alias = find_by_path(devs)
      if not dev_with_alias then
        pending("no discovered device with a by-path alias")
      end

      local dev = find_all(dev_with_alias.path_aliases[1])
      assert.Table(dev) ---@cast dev -?
      assert.Equal(1, #dev)
      assert.Equal(dev_with_alias.path, dev[1].path)
    end)
  end)

  describe("device_info", function()
    local device_info = evdev.devices.device_info

    it("returns device metadata", function()
      local info = assert(device_info(mouse.path))
      assert.Equal(mouse.path, info.path)
      assert.Equal("evdev test mouse", info.name)
    end)

    it("returns nil for a missing path", function()
      local dev, err = device_info("/dev/input/evdev-lua-test-missing")
      assert.Nil(dev)
      assert.String(err)
    end)

    it("errors on a non-string path", function()
      assert.Error(function()
        device_info(false) ---@diagnostic disable-line
      end)
    end)
  end)
end)
