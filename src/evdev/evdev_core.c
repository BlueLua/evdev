#include "core.h"

static const luaL_Reg evdev_core_functions[] = {
    {"list_devices", evdev_list_devices},
    {"device_info", evdev_device_info},
    {"open_device", evdev_open_device},
    {"poll_devices", evdev_poll_devices},
    {"create_uinput", evdev_create_uinput},
    {"list_aliases", evdev_list_aliases},
    {NULL, NULL},
};

int luaopen_evdev__core(lua_State *L) {
  evdev_register_metatable(L, EVDEV_DEVICE_MT, evdev_device_methods,
                           evdev_device_meta);
  evdev_register_metatable(L, EVDEV_UINPUT_MT, evdev_uinput_methods,
                           evdev_uinput_meta);
  luaL_newlib(L, evdev_core_functions);
  return 1;
}
