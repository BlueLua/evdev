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
    ["evdev._util"] = "src/evdev/_util.lua",
    ["evdev.device"] = "src/evdev/device.lua",
    ["evdev.devices"] = "src/evdev/devices.lua",
    ["evdev.ecodes"] = "src/evdev/ecodes.lua",
    ["evdev.events"] = "src/evdev/events.lua",
    ["evdev"] = "src/evdev/init.lua",
    ["evdev.selector"] = "src/evdev/selector.lua",
    ["evdev.uinput"] = "src/evdev/uinput.lua",
    ["bluelua-evdev._core"] = {
      sources = {
        "src/evdev/device.c",
        "src/evdev/devices.c",
        "src/evdev/evdev_core.c",
        "src/evdev/selector.c",
        "src/evdev/uinput.c",
        "src/evdev/util.c",
      },
    },
    ["bluelua-evdev.types/_enums"] = "types/_enums.d.lua",
    ["bluelua-evdev.types/device"] = "types/device.d.lua",
    ["bluelua-evdev.types/devices"] = "types/devices.d.lua",
    ["bluelua-evdev.types/ecodes"] = "types/ecodes.d.lua",
    ["bluelua-evdev.types/evdev"] = "types/evdev.d.lua",
    ["bluelua-evdev.types/events"] = "types/events.d.lua",
    ["bluelua-evdev.types/selector"] = "types/selector.d.lua",
    ["bluelua-evdev.types/uinput"] = "types/uinput.d.lua",
  },
}
