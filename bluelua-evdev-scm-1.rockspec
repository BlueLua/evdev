package = "bluelua-evdev"
version = "scm-1"

source = {
  url = "git+https://github.com/BlueLua/evdev.git",
}

description = {
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    evdev = "src/evdev/init.lua",
    ["evdev._util"] = "src/evdev/_util.lua",
    ["evdev.device"] = "src/evdev/device.lua",
    ["evdev.devices"] = "src/evdev/devices.lua",
    ["evdev.ecodes"] = "src/evdev/ecodes.lua",
    ["evdev.events"] = "src/evdev/events.lua",
    ["evdev.selector"] = "src/evdev/selector.lua",
    ["evdev.uinput"] = "src/evdev/uinput.lua",
    ["evdev._core"] = {
      sources = {
        "src/evdev/evdev_core.c",
        "src/evdev/util.c",
        "src/evdev/devices.c",
        "src/evdev/device.c",
        "src/evdev/selector.c",
        "src/evdev/uinput.c",
      },
    },
  },
}
