local fmt = string.format

local M = {}

function M.tbl_copy(input)
  local output = {}
  for k, v in pairs(input) do
    output[k] = v
  end
  return output
end

function M.tbl_update(dst, src)
  for k, v in pairs(src) do
    dst[k] = v
  end
  return dst
end

function M.tbl_keys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  return keys
end

---@type fun <T> (lbl:string?, v:any, tp:type, optional:boolean?):(value:T)
function M.validate(lbl, v, tp, optional)
  local tv = type(v)
  if tv == tp or (optional and v == nil) then
    return v
  end
  error(fmt("%s: (%s expected, got %s)", lbl, tp, tv), 3)
end

return M
