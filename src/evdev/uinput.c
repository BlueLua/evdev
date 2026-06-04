#include "core.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static int evdev_table_has_field(lua_State *L, int table_index,
                                 const char *field) {
  int has_field;

  lua_getfield(L, table_index, field);
  has_field = !lua_isnil(L, -1);
  lua_pop(L, 1);
  return has_field;
}

static int evdev_ioctl_bit(int fd, unsigned long request, int value,
                           const char *label, lua_State *L) {
  if (ioctl(fd, request, value) < 0) {
    return evdev_push_errno(L, label, NULL);
  }

  return 0;
}

static int evdev_enable_event_types(lua_State *L, int fd, int spec_index) {
  int i;
  size_t len;

  lua_getfield(L, spec_index, "event_types");
  if (lua_isnil(L, -1)) {
    int has_keys;
    int has_rels;

    lua_pop(L, 1);
    if (evdev_ioctl_bit(fd, UI_SET_EVBIT, EV_SYN, "enable EV_SYN", L) != 0) {
      return 2;
    }

    has_keys = evdev_table_has_field(L, spec_index, "keys");
    has_rels = evdev_table_has_field(L, spec_index, "rels");
    if ((has_keys || !has_rels) &&
        evdev_ioctl_bit(fd, UI_SET_EVBIT, EV_KEY, "enable EV_KEY", L) != 0) {
      return 2;
    }
    if (has_rels &&
        evdev_ioctl_bit(fd, UI_SET_EVBIT, EV_REL, "enable EV_REL", L) != 0) {
      return 2;
    }
    return 0;
  }

  luaL_checktype(L, -1, LUA_TTABLE);
  len = lua_rawlen(L, -1);
  for (i = 1; (size_t)i <= len; i++) {
    int event_type;

    lua_rawgeti(L, -1, i);
    event_type = (int)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    if (evdev_ioctl_bit(fd, UI_SET_EVBIT, event_type, "enable event type", L) !=
        0) {
      lua_remove(L, -3);
      return 2;
    }
  }

  lua_pop(L, 1);
  return 0;
}

static int evdev_enable_code_bits(lua_State *L, int fd, int spec_index,
                                  const char *field, unsigned long request,
                                  const char *label) {
  int i;
  size_t len;

  lua_getfield(L, spec_index, field);
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }

  luaL_checktype(L, -1, LUA_TTABLE);
  len = lua_rawlen(L, -1);
  for (i = 1; (size_t)i <= len; i++) {
    int code;

    lua_rawgeti(L, -1, i);
    code = (int)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    if (evdev_ioctl_bit(fd, request, code, label, L) != 0) {
      lua_remove(L, -3);
      return 2;
    }
  }

  lua_pop(L, 1);
  return 0;
}

static int evdev_enable_keys(lua_State *L, int fd, int spec_index) {
  return evdev_enable_code_bits(L, fd, spec_index, "keys", UI_SET_KEYBIT,
                                "enable key");
}

static int evdev_enable_rels(lua_State *L, int fd, int spec_index) {
  return evdev_enable_code_bits(L, fd, spec_index, "rels", UI_SET_RELBIT,
                                "enable relative axis");
}

static int evdev_is_event_node_name(const char *name) {
  return strncmp(name, "event", 5) == 0 && name[5] != '\0';
}

static int evdev_find_uinput_event_path(const char *sysname, char *path,
                                        size_t path_len) {
  char sysfs_path[PATH_MAX];
  DIR *dir;
  struct dirent *entry;
  int written;

  written = snprintf(sysfs_path, sizeof(sysfs_path),
                     "/sys/devices/virtual/input/%s", sysname);
  if (written < 0 || (size_t)written >= sizeof(sysfs_path)) {
    errno = ENAMETOOLONG;
    return -1;
  }

  dir = opendir(sysfs_path);
  if (dir == NULL) {
    return -1;
  }

  while ((entry = readdir(dir)) != NULL) {
    if (!evdev_is_event_node_name(entry->d_name)) {
      continue;
    }

    written = snprintf(path, path_len, "/dev/input/%s", entry->d_name);
    (void)closedir(dir);
    if (written < 0 || (size_t)written >= path_len) {
      errno = ENAMETOOLONG;
      return -1;
    }
    return 0;
  }

  (void)closedir(dir);
  errno = ENOENT;
  return -1;
}

static void evdev_sleep_ms(int ms) {
  int rc;

  do {
    rc = poll(NULL, 0, ms);
  } while (rc < 0 && errno == EINTR);
}

static int evdev_wait_for_uinput_event_path(const char *sysname, char *path,
                                            size_t path_len) {
  int i;
  int saved_errno = ENOENT;

  for (i = 0; i < 50; i++) {
    if (evdev_find_uinput_event_path(sysname, path, path_len) == 0) {
      int test_fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
      if (test_fd >= 0) {
        close(test_fd);
        return 0;
      }
      saved_errno = errno;
    } else {
      saved_errno = errno;
    }

    if (saved_errno != ENOENT && saved_errno != ENOTDIR &&
        saved_errno != EACCES) {
      break;
    }
    if (i + 1 < 50) {
      evdev_sleep_ms(10);
    }
  }

  errno = saved_errno;
  return -1;
}

static int evdev_cache_uinput_path(lua_State *L, evdev_uinput_t *uinput) {
  char sysname[64];
  char path[PATH_MAX];

  if (uinput->path != NULL) {
    return 0;
  }

  memset(sysname, 0, sizeof(sysname));
  if (ioctl(uinput->fd, UI_GET_SYSNAME(sizeof(sysname)), sysname) < 0) {
    return evdev_push_errno(L, "get uinput sysname", NULL);
  }

  if (evdev_wait_for_uinput_event_path(sysname, path, sizeof(path)) < 0) {
    return evdev_push_errno(L, "find uinput event node", sysname);
  }

  uinput->path = evdev_strdup(path);
  if (uinput->path == NULL) {
    return evdev_push_error(L, "out of memory");
  }

  return 0;
}

int evdev_create_uinput(lua_State *L) {
  int spec_index;
  const char *path;
  const char *name;
  int fd;
  int result;
  struct uinput_user_dev setup;
  evdev_uinput_t *uinput;

  luaL_checktype(L, 1, LUA_TTABLE);
  spec_index = 1;
  path = evdev_get_table_string_field(L, spec_index, "path", "/dev/uinput");
  name = evdev_get_table_string_field(L, spec_index, "name",
                                      "Lua evdev virtual keyboard");

  fd = evdev_open_cloexec(path, O_WRONLY | O_NONBLOCK);
  if (fd < 0) {
    return evdev_push_errno(L, "open", path);
  }

  result = evdev_enable_event_types(L, fd, spec_index);
  if (result != 0) {
    evdev_close_fd(&fd);
    return result;
  }

  result = evdev_enable_keys(L, fd, spec_index);
  if (result != 0) {
    evdev_close_fd(&fd);
    return result;
  }

  result = evdev_enable_rels(L, fd, spec_index);
  if (result != 0) {
    evdev_close_fd(&fd);
    return result;
  }

  memset(&setup, 0, sizeof(setup));
  snprintf(setup.name, UINPUT_MAX_NAME_SIZE, "%s", name);
  setup.id.bustype = (unsigned short)evdev_get_table_integer_field(
      L, spec_index, "bustype", BUS_USB);
  setup.id.vendor = (unsigned short)evdev_get_table_integer_field(
      L, spec_index, "vendor", 0x1209);
  setup.id.product = (unsigned short)evdev_get_table_integer_field(
      L, spec_index, "product", 0xE7DE);
  setup.id.version = (unsigned short)evdev_get_table_integer_field(
      L, spec_index, "version", 1);

  if (evdev_write_all(fd, &setup, sizeof(setup)) < 0) {
    result = evdev_push_errno(L, "configure uinput", path);
    evdev_close_fd(&fd);
    return result;
  }

  if (ioctl(fd, UI_DEV_CREATE) < 0) {
    result = evdev_push_errno(L, "create uinput device", path);
    evdev_close_fd(&fd);
    return result;
  }

  uinput = (evdev_uinput_t *)lua_newuserdata(L, sizeof(*uinput));
  uinput->fd = fd;
  uinput->created = 1;
  uinput->path = NULL;
  luaL_setmetatable(L, EVDEV_UINPUT_MT);

  result = evdev_cache_uinput_path(L, uinput);
  if (result != 0) {
    (void)ioctl(fd, UI_DEV_DESTROY);
    evdev_close_fd(&fd);
    uinput->fd = -1;
    uinput->created = 0;
    return result;
  }

  return 1;
}

static int evdev_emit_raw(lua_State *L, int fd, uint16_t type, uint16_t code,
                          int32_t value) {
  struct input_event event;

  memset(&event, 0, sizeof(event));
  event.type = type;
  event.code = code;
  event.value = value;

  if (evdev_write_all(fd, &event, sizeof(event)) < 0) {
    return evdev_push_errno(L, "write uinput event", NULL);
  }

  lua_pushboolean(L, 1);
  return 1;
}

static int evdev_uinput_emit(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);
  int event_type;
  int event_code;
  int event_value;
  int err_result;

  err_result = evdev_check_open_uinput(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  event_type = (int)luaL_checkinteger(L, 2);
  event_code = (int)luaL_checkinteger(L, 3);
  event_value = (int)luaL_checkinteger(L, 4);

  return evdev_emit_raw(L, uinput->fd, (uint16_t)event_type,
                        (uint16_t)event_code, (int32_t)event_value);
}

static int evdev_uinput_sync(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);
  int err_result;

  err_result = evdev_check_open_uinput(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  return evdev_emit_raw(L, uinput->fd, EV_SYN, SYN_REPORT, 0);
}

static int evdev_push_repeat_unsupported(lua_State *L, const char *action,
                                         const char *path) {
  lua_pushnil(L);
  lua_pushfstring(L, "%s %s: device does not support repeat settings", action,
                  path != NULL ? path : "<unknown>");
  return 2;
}

static int evdev_uinput_open_event_node(lua_State *L, evdev_uinput_t *uinput,
                                        int flags) {
  int err_result;
  int fd;

  err_result = evdev_cache_uinput_path(L, uinput);
  if (err_result != 0) {
    return -1;
  }

  fd = evdev_open_cloexec(uinput->path, flags | O_NONBLOCK);
  if (fd < 0) {
    (void)evdev_push_errno(L, "open", uinput->path);
    return -1;
  }

  return fd;
}

static int evdev_uinput_set_repeat(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);
  unsigned int repeat[2];
  lua_Integer delay = luaL_checkinteger(L, 2);
  lua_Integer period = luaL_checkinteger(L, 3);
  int err_result;
  int fd;

  luaL_argcheck(L, delay >= 0, 2, "delay must be non-negative");
  luaL_argcheck(L, period >= 0, 3, "period must be non-negative");

  err_result = evdev_check_open_uinput(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  fd = evdev_uinput_open_event_node(L, uinput, O_RDWR);
  if (fd < 0) {
    return 2;
  }

  repeat[0] = (unsigned int)delay;
  repeat[1] = (unsigned int)period;

  if (ioctl(fd, EVIOCSREP, repeat) < 0) {
    int saved_errno = errno;
    evdev_close_fd(&fd);
    errno = saved_errno;
    if (errno == ENOSYS || errno == ENOTTY || errno == EINVAL) {
      return evdev_push_repeat_unsupported(L, "set repeat", uinput->path);
    }
    return evdev_push_errno(L, "set repeat", uinput->path);
  }

  evdev_close_fd(&fd);
  lua_pushboolean(L, 1);
  return 1;
}

static int evdev_uinput_get_repeat(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);
  unsigned int repeat[2] = {0, 0};
  int err_result;
  int fd;

  err_result = evdev_check_open_uinput(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  fd = evdev_uinput_open_event_node(L, uinput, O_RDONLY);
  if (fd < 0) {
    return 2;
  }

  if (ioctl(fd, EVIOCGREP, repeat) < 0) {
    int saved_errno = errno;
    evdev_close_fd(&fd);
    errno = saved_errno;
    if (errno == ENOSYS || errno == ENOTTY || errno == EINVAL) {
      return evdev_push_repeat_unsupported(L, "get repeat", uinput->path);
    }
    return evdev_push_errno(L, "get repeat", uinput->path);
  }

  evdev_close_fd(&fd);
  lua_pushinteger(L, repeat[0]);
  lua_pushinteger(L, repeat[1]);
  return 2;
}

static int evdev_uinput_close(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);
  int destroy_errno = 0;

  if (uinput->fd >= 0) {
    if (uinput->created && ioctl(uinput->fd, UI_DEV_DESTROY) < 0) {
      destroy_errno = errno;
    }
    evdev_close_fd(&uinput->fd);
    uinput->created = 0;
  }
  free(uinput->path);
  uinput->path = NULL;

  if (destroy_errno != 0) {
    lua_pushnil(L);
    lua_pushfstring(L, "destroy uinput device: %s", strerror(destroy_errno));
    return 2;
  }

  lua_pushboolean(L, 1);
  return 1;
}

static int evdev_uinput_gc(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);

  if (uinput->fd >= 0) {
    if (uinput->created) {
      (void)ioctl(uinput->fd, UI_DEV_DESTROY);
    }
    evdev_close_fd(&uinput->fd);
    uinput->created = 0;
  }

  free(uinput->path);
  uinput->path = NULL;
  return 0;
}

static int evdev_uinput_is_open(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);

  lua_pushboolean(L, uinput->fd >= 0);
  return 1;
}

static int evdev_uinput_get_path(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);
  int err_result;

  err_result = evdev_check_open_uinput(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  err_result = evdev_cache_uinput_path(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  lua_pushstring(L, uinput->path);
  return 1;
}

static int evdev_uinput_info(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);
  int err_result;
  int fd;

  err_result = evdev_check_open_uinput(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  err_result = evdev_cache_uinput_path(L, uinput);
  if (err_result != 0) {
    return err_result;
  }

  fd = evdev_open_cloexec(uinput->path, O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    return evdev_push_errno(L, "open", uinput->path);
  }

  evdev_push_device_info(L, fd, uinput->path);
  evdev_close_fd(&fd);
  return 1;
}

static int evdev_uinput_fd(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);

  if (uinput->fd < 0) {
    lua_pushnil(L);
  } else {
    lua_pushinteger(L, uinput->fd);
  }

  return 1;
}

static int evdev_uinput_tostring(lua_State *L) {
  evdev_uinput_t *uinput = evdev_check_uinput(L, 1);

  if (uinput->fd >= 0) {
    lua_pushfstring(L, "evdev.uinput(fd=%d)", uinput->fd);
  } else {
    lua_pushliteral(L, "evdev.uinput(closed)");
  }

  return 1;
}

const luaL_Reg evdev_uinput_methods[] = {
    {"emit", evdev_uinput_emit},
    {"sync", evdev_uinput_sync},
    {"set_repeat", evdev_uinput_set_repeat},
    {"get_repeat", evdev_uinput_get_repeat},
    {"close", evdev_uinput_close},
    {"is_open", evdev_uinput_is_open},
    {"path", evdev_uinput_get_path},
    {"info", evdev_uinput_info},
    {"fd", evdev_uinput_fd},
    {NULL, NULL},
};

const luaL_Reg evdev_uinput_meta[] = {
    {"__gc", evdev_uinput_gc},
    {"__tostring", evdev_uinput_tostring},
    {NULL, NULL},
};
