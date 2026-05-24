#include "core.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>

int evdev_open_device(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  int fd;
  int saved_errno;
  evdev_device_t *device;

  fd = evdev_open_cloexec(path, O_RDWR | O_NONBLOCK);
  if (fd < 0) {
    saved_errno = errno;
    if (saved_errno == EACCES || saved_errno == EPERM || saved_errno == EROFS) {
      fd = evdev_open_cloexec(path, O_RDONLY | O_NONBLOCK);
    }
  }

  if (fd < 0) {
    return evdev_push_errno(L, "open", path);
  }

  device = (evdev_device_t *)lua_newuserdata(L, sizeof(*device));
  device->fd = fd;
  device->grabbed = 0;
  device->path = evdev_strdup(path);
  if (device->path == NULL) {
    evdev_close_fd(&fd);
    return evdev_push_error(L, "out of memory");
  }

  luaL_setmetatable(L, EVDEV_DEVICE_MT);
  return 1;
}

static int evdev_device_close(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);

  if (device->fd >= 0) {
    if (device->grabbed) {
      (void)ioctl(device->fd, EVIOCGRAB, 0);
      device->grabbed = 0;
    }
    evdev_close_fd(&device->fd);
  }

  lua_pushboolean(L, 1);
  return 1;
}

static int evdev_device_gc(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);

  if (device->fd >= 0) {
    if (device->grabbed) {
      (void)ioctl(device->fd, EVIOCGRAB, 0);
    }
    evdev_close_fd(&device->fd);
  }

  free(device->path);
  device->path = NULL;
  device->grabbed = 0;
  return 0;
}

static int evdev_device_is_open(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);

  lua_pushboolean(L, device->fd >= 0);
  return 1;
}

static int evdev_device_fd(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);

  if (device->fd < 0) {
    lua_pushnil(L);
  } else {
    lua_pushinteger(L, device->fd);
  }

  return 1;
}

static int evdev_device_grab(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  int err_result;

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  if (ioctl(device->fd, EVIOCGRAB, 1) < 0) {
    if (errno == EBUSY) {
      lua_pushnil(L);
      lua_pushfstring(L, "grab %s: device is already grabbed",
                      device->path != NULL ? device->path : "<unknown>");
      return 2;
    }
    return evdev_push_errno(L, "grab", device->path);
  }

  device->grabbed = 1;
  lua_pushboolean(L, 1);
  return 1;
}

static int evdev_device_ungrab(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  int err_result;

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  if (!device->grabbed) {
    lua_pushnil(L);
    lua_pushfstring(L, "ungrab %s: device is not grabbed",
                    device->path != NULL ? device->path : "<unknown>");
    return 2;
  }

  if (ioctl(device->fd, EVIOCGRAB, 0) < 0) {
    return evdev_push_errno(L, "ungrab", device->path);
  }

  device->grabbed = 0;
  lua_pushboolean(L, 1);
  return 1;
}

static int evdev_push_repeat_unsupported(lua_State *L, const char *action,
                                         const char *path) {
  lua_pushnil(L);
  lua_pushfstring(L, "%s %s: device does not support repeat settings", action,
                  path != NULL ? path : "<unknown>");
  return 2;
}

static int evdev_device_set_repeat(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  unsigned int repeat[2];
  lua_Integer delay = luaL_checkinteger(L, 2);
  lua_Integer period = luaL_checkinteger(L, 3);
  int err_result;

  luaL_argcheck(L, delay >= 0, 2, "delay must be non-negative");
  luaL_argcheck(L, period >= 0, 3, "period must be non-negative");

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  repeat[0] = (unsigned int)delay;
  repeat[1] = (unsigned int)period;

  if (ioctl(device->fd, EVIOCSREP, repeat) < 0) {
    if (errno == ENOSYS || errno == ENOTTY || errno == EINVAL) {
      return evdev_push_repeat_unsupported(L, "set repeat", device->path);
    }
    return evdev_push_errno(L, "set repeat", device->path);
  }

  lua_pushboolean(L, 1);
  return 1;
}

static int evdev_device_get_repeat(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  unsigned int repeat[2] = {0, 0};
  int err_result;

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  if (ioctl(device->fd, EVIOCGREP, repeat) < 0) {
    if (errno == ENOSYS || errno == ENOTTY || errno == EINVAL) {
      return evdev_push_repeat_unsupported(L, "get repeat", device->path);
    }
    return evdev_push_errno(L, "get repeat", device->path);
  }

  lua_pushinteger(L, repeat[0]);
  lua_pushinteger(L, repeat[1]);
  return 2;
}

static int evdev_device_info_method(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  int err_result;

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  evdev_push_device_info(L, device->fd, device->path);
  return 1;
}

static int evdev_poll_forever(struct pollfd *fds, nfds_t count) {
  int rc;

  do {
    rc = poll(fds, count, -1);
  } while (rc < 0 && errno == EINTR);

  return rc;
}

static int evdev_push_poll_revents_error(lua_State *L, const char *path,
                                         short revents) {
  lua_pushnil(L);
  lua_pushfstring(L, "poll failed for %s: revents=0x%x",
                  path != NULL ? path : "<unknown>", (unsigned int)revents);
  return 2;
}

static int evdev_device_poll(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  struct pollfd pfd;
  int err_result;

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  pfd.fd = device->fd;
  pfd.events = POLLIN;
  pfd.revents = 0;

  if (evdev_poll_forever(&pfd, 1) < 0) {
    return evdev_push_errno(L, "poll", device->path);
  }

  if ((pfd.revents & POLLIN) != 0) {
    lua_pushboolean(L, 1);
    return 1;
  }

  return evdev_push_poll_revents_error(L, device->path, pfd.revents);
}

int evdev_poll_devices(lua_State *L) {
  size_t len;
  struct pollfd *pfds;
  size_t i;
  int out;

  luaL_checktype(L, 1, LUA_TTABLE);
  len = lua_rawlen(L, 1);
  if (len == 0) {
    return evdev_push_error(L, "devices must not be empty");
  }
  if ((size_t)((nfds_t)len) != len) {
    return evdev_push_error(L, "too many devices");
  }

  for (i = 1; i <= len; i++) {
    evdev_device_t *device;
    int err_result;

    lua_rawgeti(L, 1, (lua_Integer)i);
    device = evdev_check_device(L, -1);
    err_result = evdev_check_open_device(L, device);
    if (err_result != 0) {
      lua_remove(L, -3);
      return err_result;
    }
    lua_pop(L, 1);
  }

  pfds = (struct pollfd *)calloc(len, sizeof(*pfds));
  if (pfds == NULL) {
    return evdev_push_error(L, "out of memory");
  }

  for (i = 1; i <= len; i++) {
    evdev_device_t *device;

    lua_rawgeti(L, 1, (lua_Integer)i);
    device = evdev_check_device(L, -1);
    pfds[i - 1].fd = device->fd;
    pfds[i - 1].events = POLLIN;
    lua_pop(L, 1);
  }

  if (evdev_poll_forever(pfds, (nfds_t)len) < 0) {
    free(pfds);
    return evdev_push_errno(L, "poll", NULL);
  }

  for (i = 1; i <= len; i++) {
    short revents = pfds[i - 1].revents;

    if ((revents & (POLLERR | POLLHUP | POLLNVAL)) != 0) {
      char label[64];
      snprintf(label, sizeof(label), "device #%lu", (unsigned long)i);
      free(pfds);
      return evdev_push_poll_revents_error(L, label, revents);
    }
  }

  lua_newtable(L);
  out = 1;
  for (i = 1; i <= len; i++) {
    if ((pfds[i - 1].revents & POLLIN) != 0) {
      lua_pushinteger(L, (lua_Integer)i);
      lua_rawseti(L, -2, out++);
    }
  }

  free(pfds);
  return 1;
}

static int evdev_device_read(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  struct input_event event;
  ssize_t got;
  int err_result;

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  do {
    got = read(device->fd, &event, sizeof(event));
  } while (got < 0 && errno == EINTR);

  if (got < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      lua_pushnil(L);
      return 1;
    }

    return evdev_push_errno(L, "read", device->path);
  }

  if (got == 0) {
    lua_pushnil(L);
    return 1;
  }

  if ((size_t)got != sizeof(event)) {
    return evdev_push_error(L, "short read from input device");
  }

  lua_newtable(L);
  lua_pushvalue(L, 1);
  lua_setfield(L, -2, "device");
  evdev_set_integer_field(L, "type", event.type);
  evdev_set_integer_field(L, "code", event.code);
  evdev_set_integer_field(L, "value", event.value);
  evdev_set_integer_field(L, "sec", (lua_Integer)event.input_event_sec);
  evdev_set_integer_field(L, "usec", (lua_Integer)event.input_event_usec);
  return 1;
}

static int evdev_device_flush(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);
  struct input_event event;
  lua_Integer count = 0;
  int err_result;

  err_result = evdev_check_open_device(L, device);
  if (err_result != 0) {
    return err_result;
  }

  for (;;) {
    ssize_t got;

    do {
      got = read(device->fd, &event, sizeof(event));
    } while (got < 0 && errno == EINTR);

    if (got < 0) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        lua_pushinteger(L, count);
        return 1;
      }

      return evdev_push_errno(L, "flush", device->path);
    }

    if (got == 0) {
      lua_pushinteger(L, count);
      return 1;
    }

    if ((size_t)got != sizeof(event)) {
      return evdev_push_error(L, "short read from input device");
    }

    count++;
  }
}

static int evdev_device_tostring(lua_State *L) {
  evdev_device_t *device = evdev_check_device(L, 1);

  if (device->fd >= 0) {
    lua_pushfstring(L, "evdev.device(%s, fd=%d)",
                    device->path != NULL ? device->path : "<unknown>",
                    device->fd);
  } else {
    lua_pushfstring(L, "evdev.device(%s, closed)",
                    device->path != NULL ? device->path : "<unknown>");
  }

  return 1;
}

const luaL_Reg evdev_device_methods[] = {
    {"close", evdev_device_close},
    {"is_open", evdev_device_is_open},
    {"fd", evdev_device_fd},
    {"grab", evdev_device_grab},
    {"ungrab", evdev_device_ungrab},
    {"set_repeat", evdev_device_set_repeat},
    {"get_repeat", evdev_device_get_repeat},
    {"info", evdev_device_info_method},
    {"poll", evdev_device_poll},
    {"read", evdev_device_read},
    {"flush", evdev_device_flush},
    {NULL, NULL},
};

const luaL_Reg evdev_device_meta[] = {
    {"__gc", evdev_device_gc},
    {"__tostring", evdev_device_tostring},
    {NULL, NULL},
};
