local Utils = {}


--- Toggles a given boolean value based on given parameter.
-- @param param_pct number:  param value (should generate value 0 - 100)
-- @param val number:  the value to flip given boolean value
-- @return boolean:
function Utils.rand_occurrence(param_pct, val)
  local r = math.random()
  local bool_val = not val

  if (r < param_pct / 100) then
    bool_val = val
  end

  return bool_val
end


return Utils
