#include "core.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if LUA_VERSION_NUM == 501
void luaL_setmetatable(lua_State *L, const char *name) {
  luaL_getmetatable(L, name);
  lua_setmetatable(L, -2);
}
#endif

char *evdev_strdup(const char *value) {
  size_t len;
  char *copy;

  if (value == NULL) {
    return NULL;
  }

  len = strlen(value) + 1;
  copy = (char *)malloc(len);
  if (copy == NULL) {
    return NULL;
  }

  memcpy(copy, value, len);
  return copy;
}

int evdev_push_error(lua_State *L, const char *message) {
  lua_pushnil(L);
  lua_pushstring(L, message);
  return 2;
}

int evdev_push_errno(lua_State *L, const char *action, const char *path) {
  int err = errno;

  lua_pushnil(L);
  if (path != NULL) {
    lua_pushfstring(L, "%s %s: %s", action, path, strerror(err));
  } else {
    lua_pushfstring(L, "%s: %s", action, strerror(err));
  }
  return 2;
}

int evdev_open_cloexec(const char *path, int flags) {
  int fd = open(path, flags | O_CLOEXEC);
  if (fd < 0) {
    return -1;
  }

#if O_CLOEXEC == 0
  (void)fcntl(fd, F_SETFD, FD_CLOEXEC);
#endif

  return fd;
}

void evdev_close_fd(int *fd) {
  if (*fd >= 0) {
    (void)close(*fd);
    *fd = -1;
  }
}

evdev_device_t *evdev_check_device(lua_State *L, int index) {
  return (evdev_device_t *)luaL_checkudata(L, index, EVDEV_DEVICE_MT);
}

evdev_uinput_t *evdev_check_uinput(lua_State *L, int index) {
  return (evdev_uinput_t *)luaL_checkudata(L, index, EVDEV_UINPUT_MT);
}

int evdev_check_open_device(lua_State *L, evdev_device_t *device) {
  if (device->fd < 0) {
    return evdev_push_error(L, "device is closed");
  }
  return 0;
}

int evdev_check_open_uinput(lua_State *L, evdev_uinput_t *uinput) {
  if (uinput->fd < 0) {
    return evdev_push_error(L, "uinput device is closed");
  }
  return 0;
}

void evdev_set_string_field(lua_State *L, const char *field,
                            const char *value) {
  if (value == NULL || value[0] == '\0') {
    return;
  }

  lua_pushstring(L, value);
  lua_setfield(L, -2, field);
}

void evdev_set_integer_field(lua_State *L, const char *field,
                             lua_Integer value) {
  lua_pushinteger(L, value);
  lua_setfield(L, -2, field);
}

void evdev_set_boolean_field(lua_State *L, const char *field, int value) {
  lua_pushboolean(L, value);
  lua_setfield(L, -2, field);
}

int evdev_get_table_integer_field(lua_State *L, int table_index,
                                  const char *field, int fallback) {
  int value;

  lua_getfield(L, table_index, field);
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    return fallback;
  }

  value = (int)luaL_checkinteger(L, -1);
  lua_pop(L, 1);
  return value;
}

const char *evdev_get_table_string_field(lua_State *L, int table_index,
                                         const char *field,
                                         const char *fallback) {
  const char *value;

  lua_getfield(L, table_index, field);
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    return fallback;
  }

  value = luaL_checkstring(L, -1);
  lua_pop(L, 1);
  return value;
}

int evdev_write_all(int fd, const void *buffer, size_t len) {
  const char *cursor = (const char *)buffer;
  size_t remaining = len;

  while (remaining > 0) {
    ssize_t written = write(fd, cursor, remaining);

    if (written < 0) {
      if (errno == EINTR) {
        continue;
      }
      return -1;
    }

    if (written == 0) {
      errno = EIO;
      return -1;
    }

    cursor += written;
    remaining -= (size_t)written;
  }

  return 0;
}

void evdev_register_metatable(lua_State *L, const char *name,
                              const luaL_Reg *methods, const luaL_Reg *meta) {
  const luaL_Reg *reg;

  luaL_newmetatable(L, name);
  lua_newtable(L);
  for (reg = methods; reg->name != NULL; reg++) {
    lua_pushcfunction(L, reg->func);
    lua_setfield(L, -2, reg->name);
  }
  lua_setfield(L, -2, "__index");

  for (reg = meta; reg->name != NULL; reg++) {
    lua_pushcfunction(L, reg->func);
    lua_setfield(L, -2, reg->name);
  }

  lua_pop(L, 1);
}
