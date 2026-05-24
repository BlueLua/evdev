#ifndef EVDEV_CORE_H
#define EVDEV_CORE_H

#if !defined(__linux__)
#error "evdev requires Linux input/uinput headers and runtime support"
#endif

#include <fcntl.h>
#include <limits.h>
#include <stddef.h>

#include <lauxlib.h>
#include <lua.h>

#if LUA_VERSION_NUM == 501
#define lua_rawlen lua_objlen
#define luaL_newlib(L, funcs)                                                  \
  (lua_newtable((L)), luaL_register((L), NULL, (funcs)))
void luaL_setmetatable(lua_State *L, const char *name);
#endif

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#define EVDEV_DEVICE_MT "evdev.core.device"
#define EVDEV_UINPUT_MT "evdev.core.uinput"

typedef struct {
  int fd;
  int grabbed;
  char *path;
} evdev_device_t;

typedef struct {
  int fd;
  int created;
  char *path;
} evdev_uinput_t;

char *evdev_strdup(const char *value);
int evdev_push_error(lua_State *L, const char *message);
int evdev_push_errno(lua_State *L, const char *action, const char *path);
int evdev_open_cloexec(const char *path, int flags);
void evdev_close_fd(int *fd);
evdev_device_t *evdev_check_device(lua_State *L, int index);
evdev_uinput_t *evdev_check_uinput(lua_State *L, int index);
int evdev_check_open_device(lua_State *L, evdev_device_t *device);
int evdev_check_open_uinput(lua_State *L, evdev_uinput_t *uinput);
void evdev_set_string_field(lua_State *L, const char *field, const char *value);
void evdev_set_integer_field(lua_State *L, const char *field,
                             lua_Integer value);
void evdev_set_boolean_field(lua_State *L, const char *field, int value);
int evdev_get_table_integer_field(lua_State *L, int table_index,
                                  const char *field, int fallback);
const char *evdev_get_table_string_field(lua_State *L, int table_index,
                                         const char *field,
                                         const char *fallback);
int evdev_write_all(int fd, const void *buffer, size_t len);
void evdev_register_metatable(lua_State *L, const char *name,
                              const luaL_Reg *methods, const luaL_Reg *meta);

void evdev_push_device_info(lua_State *L, int fd, const char *path);

int evdev_list_devices(lua_State *L);
int evdev_list_aliases(lua_State *L);
int evdev_device_info(lua_State *L);
int evdev_open_device(lua_State *L);
int evdev_poll_devices(lua_State *L);
int evdev_create_uinput(lua_State *L);

extern const luaL_Reg evdev_device_methods[];
extern const luaL_Reg evdev_device_meta[];
extern const luaL_Reg evdev_uinput_methods[];
extern const luaL_Reg evdev_uinput_meta[];

#endif
