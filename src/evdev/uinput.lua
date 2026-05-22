---@diagnostic disable: inject-field

local evdev = require "evdev"

local ecodes = evdev.ecodes
local util = evdev._util

local create_uinput = evdev._core.create_uinput
local tbl_copy = util.copy
local tbl_keys = util.keys
local validate = util.validate
local fmt = string.format

---@type evdev.uinput
local M = {}

---@type evdev.UInput
local UInput = {}
UInput.__index = UInput

local closed_err = "uinput device is closed"

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

  spec.keys = spec.keys == nil and tbl_keys(allowed.keys) or spec.keys
  spec.rels = spec.rels == nil and tbl_keys(allowed.rels) or spec.rels

  if spec.event_types == nil then
    local event_types = { ecodes.EV_SYN }
    if spec.keys ~= nil then
      event_types[#event_types + 1] = ecodes.EV_KEY
    end
    if spec.rels ~= nil then
      event_types[#event_types + 1] = ecodes.EV_REL
    end
    spec.event_types = event_types
  end

  return spec
end

function M.create(spec)
  local ui, err = create_uinput(normalize(spec))
  if not ui then
    return nil, err
  end
  return setmetatable({ _core = ui }, UInput)
end

function UInput:is_open()
  local handle = self._core
  return handle ~= nil and handle:is_open()
end

function UInput:close()
  if not self:is_open() then
    return true
  end

  local ok, err = self._core:close()
  if not ok then
    return nil, err
  end

  self._core = nil
  return true
end

function UInput:emit(etype, ecode, evalue)
  validate("type", etype, "number")
  validate("code", ecode, "number")
  validate("value", evalue, "number")

  if not self:is_open() then
    return nil, closed_err
  end

  local ok, emit_err = self._core:emit(etype, ecode, evalue)
  if not ok then
    return nil, emit_err
  end

  return true
end

function UInput:sync()
  if not self:is_open() then
    return nil, closed_err
  end

  local ok, sync_err = self._core:sync()
  if ok == nil then
    return nil, sync_err
  end

  return true
end

function UInput:info()
  if not self:is_open() then
    return nil, closed_err
  end
  return self._core:info()
end

if _TEST then
  M._normalize = normalize
end

collect_codes()

return M
