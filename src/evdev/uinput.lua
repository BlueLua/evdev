---@diagnostic disable: inject-field

local evdev = require "evdev"

local ecodes = evdev.ecodes
local util = evdev._util

local create_uinput = evdev._core.create_uinput
local tbl_copy = util.tbl_copy
local tbl_keys = util.tbl_keys
local validate = util.validate
local fmt = string.format

---@type evdev.UInput
local UInput = {}
UInput.__index = UInput

---@type fun(dev:evdev.UInput, fname:string, ...):...
local function call_uinput(ui, fname, ...)
  local core = ui._core
  if not core then
    return nil, "uinput device is closed"
  end
  return core[fname](core, ...)
end

local function is_metacode(name)
  return name:match("_MAX$")
    or name:match("_CNT$")
    or name:match("_RESERVED$")
    or name:match("_MIN_")
    or name:match("_MAX_")
end

---@type table<string,{[integer]:true}>
local allowed = { keys = {}, rels = {}, event_types = {} }

---@type table<string,{[integer]:true}>
local ignored = { keys = {}, rels = {}, event_types = {} }

local function collect_codes()
  -- stylua: ignore
  local families = {
    { prefix = "KEY_", name = "keys"        },
    { prefix = "BTN_", name = "keys"        },
    { prefix = "REL_", name = "rels"        },
    { prefix = "EV_" , name = "event_types" },
  }

  for name, code in pairs(ecodes) do
    for _, family in ipairs(families) do
      if name:sub(1, #family.prefix) == family.prefix then
        local t = is_metacode(name) and ignored or allowed
        t[family.name][code] = true
        break
      end
    end
  end
end

local function is_repeatable_key(code)
  for name, c in pairs(ecodes) do
    if c == code and name:sub(1, 4) == "KEY_" and not is_metacode(name) then
      return true
    end
  end
  return false
end

local function has_repeatable_key(keys)
  for _, code in ipairs(keys or {}) do
    if is_repeatable_key(code) then
      return true
    end
  end
  return false
end

---@type fun(spec:evdev.uinputSpec,name:string,expected:string)
local function normalize_code_list(spec, name, expected)
  local values = spec[name]
  if values == nil then
    return
  end

  validate("spec." .. name, values, "table")

  local positions = {}
  local filtered = tbl_copy(values)

  for i, v in ipairs(values) do
    validate("spec." .. name .. "[" .. i .. "]", v, "number")
    if ignored[name][v] then
      positions[#positions + 1] = i
    elseif not allowed[name][v] then
      error(fmt("spec.%s[%d]: expected a valid %s code, got %s", name, i, expected, tostring(v)), 2)
    end
  end

  for i = #positions, 1, -1 do
    table.remove(filtered, positions[i])
  end
  spec[name] = filtered
end

---@type fun(spec:evdev.uinputSpec):(spec:evdev.uinputSpec)
local function normalize(spec)
  validate("spec", spec, "table", true)

  spec = tbl_copy(spec or {})

  validate("spec.bustype", spec.bustype, "number", true)
  validate("spec.vendor", spec.vendor, "number", true)
  validate("spec.product", spec.product, "number", true)
  validate("spec.version", spec.version, "number", true)
  validate("spec.name", spec.name, "string", true)
  validate("spec.path", spec.path, "string", true)

  normalize_code_list(spec, "keys", "KEY_* or BTN_*")
  normalize_code_list(spec, "rels", "REL_*")
  normalize_code_list(spec, "event_types", "EV_*")

  spec.keys = spec.keys and spec.keys or tbl_keys(allowed.keys)
  spec.rels = spec.rels and spec.rels or tbl_keys(allowed.rels)

  if spec.event_types == nil then
    local event_types = { ecodes.EV_SYN }
    local has_keys = spec.keys and #spec.keys > 0
    local has_rels = spec.rels and #spec.rels > 0

    event_types[#event_types + 1] = has_keys and ecodes.EV_KEY or nil
    event_types[#event_types + 1] = has_rels and ecodes.EV_REL or nil
    event_types[#event_types + 1] = has_repeatable_key(spec.keys) and ecodes.EV_REP or nil

    spec.event_types = event_types
  end

  return spec
end

function UInput:close()
  if self._core then
    local ok, err = self._core:close()
    if not ok then
      return nil, err
    end
    self._core = nil
  end
  return true
end

function UInput:emit(type, code, value)
  validate("type", type, "number")
  validate("code", code, "number")
  validate("value", value, "number")
  return call_uinput(self, "emit", type, code, value)
end

-- stylua: ignore start
function UInput:is_open() return self._core ~= nil and self._core:is_open() end
function UInput:sync()    return call_uinput(self, "sync")                  end
function UInput:info()    return call_uinput(self, "info")                  end
-- stylua: ignore end

---@type evdev.uinput
local M = {}

function M.create(spec)
  local ui, err = create_uinput(normalize(spec))
  if not ui then
    return nil, err
  end
  return setmetatable({ _core = ui }, UInput)
end

---@diagnostic disable-next-line: undefined-global
if _TEST then
  M._normalize = normalize
end

collect_codes()

return M
