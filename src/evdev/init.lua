return setmetatable({
  _VERSION = "evdev 0.1.0",
}, {
  __index = function(t, k)
    local modname = "evdev." .. tostring(k)
    local ok, v = pcall(require, modname)
    if not ok then
      error(v, 2)
    end
    return rawset(t, k, v)[k]
  end,
})
