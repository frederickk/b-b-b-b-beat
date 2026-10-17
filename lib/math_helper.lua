local Math_Helper = {}


--- Clamps given value to min and max values.
-- @tparam val {number} input value
-- @tparam min {number} minmum range
-- @tparam max {number} maximum range
function Math_Helper.clamp(val, min, max)
  return math.min(math.max(val, min), max)
end

--- Generates random number between given min and max.
-- @tparam min {number} minmum range
-- @tparam max {number} maximum range
-- returns random number as float
function Math_Helper.random(min, max)
  return ((min or 0) + math.random() * ((max or 2) - (min or 0)));
end

--- Generates random integer number between given min and max.
-- @tparam min {number} minmum range
-- @tparam max {number} maximum range
-- returns random number as float
function Math_Helper.random_int(min, max)
  return math.floor(Math_Helper.random(min, max + 1))
end

--- Generates random percent integer value.
-- @tparam param_pct: param value (should generate value 0 - 100)
-- @tparam mult: multiplier; default = 10
function Math_Helper.random_pct(param_pct, mult)
  return math.floor(math.random() * (param_pct / 100) * (mult or 10))
end


--- Rounds a number
-- @tparam num {number}
-- @tparam numDecimalPlaces {number}
function Math_Helper.round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)

  return math.floor(num * mult + 0.5) / mult
end

return Math_Helper