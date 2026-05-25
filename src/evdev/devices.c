#include "core.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static void evdev_set_id_fields(lua_State *L, const struct input_id *id) {
  evdev_set_integer_field(L, "bustype", id->bustype);
  evdev_set_integer_field(L, "vendor", id->vendor);
  evdev_set_integer_field(L, "product", id->product);
  evdev_set_integer_field(L, "version", id->version);
}

void evdev_push_device_info(lua_State *L, int fd, const char *path) {
  struct input_id id;
  char name[256];
  char phys[256];
  char uniq[256];

  memset(&id, 0, sizeof(id));
  memset(name, 0, sizeof(name));
  memset(phys, 0, sizeof(phys));
  memset(uniq, 0, sizeof(uniq));

  lua_newtable(L);
  evdev_set_string_field(L, "path", path);

  if (ioctl(fd, EVIOCGNAME(sizeof(name)), name) >= 0) {
    evdev_set_string_field(L, "name", name);
  }

  if (ioctl(fd, EVIOCGID, &id) >= 0) {
    evdev_set_id_fields(L, &id);
  }

  if (ioctl(fd, EVIOCGPHYS(sizeof(phys)), phys) >= 0) {
    evdev_set_string_field(L, "phys", phys);
  }

  if (ioctl(fd, EVIOCGUNIQ(sizeof(uniq)), uniq) >= 0) {
    evdev_set_string_field(L, "uniq", uniq);
  }
}

static int evdev_is_event_node(const char *name) {
  return strncmp(name, "event", 5) == 0 && name[5] != '\0';
}

static int evdev_is_dot_entry(const char *name) {
  return strcmp(name, ".") == 0 || strcmp(name, "..") == 0;
}

int evdev_list_devices(lua_State *L) {
  const char *dirpath = luaL_optstring(L, 1, "/dev/input");
  DIR *dir;
  struct dirent *entry;
  int index = 1;

  dir = opendir(dirpath);
  if (dir == NULL) {
    if (errno == ENOENT || errno == ENOTDIR) {
      lua_newtable(L);
      return 1;
    }

    return evdev_push_errno(L, "open", dirpath);
  }

  lua_newtable(L);

  while ((entry = readdir(dir)) != NULL) {
    char path[PATH_MAX];
    int fd;
    int written;

    if (!evdev_is_event_node(entry->d_name)) {
      continue;
    }

    written = snprintf(path, sizeof(path), "%s/%s", dirpath, entry->d_name);
    if (written < 0 || (size_t)written >= sizeof(path)) {
      continue;
    }

    fd = evdev_open_cloexec(path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
      continue;
    }

    evdev_push_device_info(L, fd, path);
    evdev_close_fd(&fd);
    lua_rawseti(L, -2, index++);
  }

  (void)closedir(dir);
  return 1;
}

int evdev_list_aliases(lua_State *L) {
  const char *dirpath = luaL_checkstring(L, 1);
  DIR *dir;
  struct dirent *entry;
  int index = 1;

  dir = opendir(dirpath);
  if (dir == NULL) {
    if (errno == ENOENT || errno == ENOTDIR) {
      lua_newtable(L);
      return 1;
    }

    return evdev_push_errno(L, "open", dirpath);
  }

  lua_newtable(L);

  while ((entry = readdir(dir)) != NULL) {
    char path[PATH_MAX];
    char target[PATH_MAX];
    const char *target_name;
    int written;

    if (evdev_is_dot_entry(entry->d_name)) {
      continue;
    }

    written = snprintf(path, sizeof(path), "%s/%s", dirpath, entry->d_name);
    if (written < 0 || (size_t)written >= sizeof(path)) {
      continue;
    }

    if (realpath(path, target) == NULL) {
      continue;
    }

    target_name = strrchr(target, '/');
    target_name = target_name == NULL ? target : target_name + 1;
    if (!evdev_is_event_node(target_name)) {
      continue;
    }

    lua_newtable(L);
    evdev_set_string_field(L, "path", path);
    evdev_set_string_field(L, "target", target);
    lua_rawseti(L, -2, index++);
  }

  (void)closedir(dir);
  return 1;
}

int evdev_device_info(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  int fd;

  fd = evdev_open_cloexec(path, O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    return evdev_push_errno(L, "open", path);
  }

  evdev_push_device_info(L, fd, path);
  evdev_close_fd(&fd);
  return 1;
}
