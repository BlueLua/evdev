#include "core.h"

#include <errno.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>

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
