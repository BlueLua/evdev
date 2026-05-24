local evdev = require "evdev"

describe("evdev module", function()
  it("exposes namespaces and entrypoints", function()
    assert.is_table(evdev)
    assert.is_table(evdev.devices)
    assert.is_table(evdev.device)
    assert.is_table(evdev.uinput)
    assert.is_table(evdev.ecodes)

    assert.is_function(evdev.devices.list_devices)
    assert.is_function(evdev.devices.inspect)
    assert.is_function(evdev.devices.find)
    assert.is_function(evdev.devices.find_all)
    assert.is_function(evdev.devices.poll)
    assert.is_function(evdev.device.open)
    assert.is_function(evdev.uinput.create)
  end)
end)
