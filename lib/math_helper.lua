local Math_Helper = {}


-- @param a {number}
-- @param b {number}
function gcd(a, b)
  while a ~= 0 do
    a, b = b % a, a;
  end

  return b;
end

-- Clamps given value to min and max values
-- @param val {number} input value
-- @param min {number} minmum range
-- @param max {number} maximum range
function Math_Helper.clamp(val, min, max)
  return math.min(math.max(val, min), max)
end

-- Generates random number between given min and max
-- @param min {number} minmum range
-- @param max {number} maximum range
-- returns random number as float
function Math_Helper.random(min, max)
  return ((min or 0) + math.random() * ((max or 2) - (min or 0)));
end

-- Generates random integer number between given min and max
-- @param min {number} minmum range
-- @param max {number} maximum range
-- returns random number as float
function Math_Helper.random_int(min, max)
  return math.floor(Math_Helper.random(min, max + 1))
end

-- Rounds a number
-- @param num {number}
-- @param numDecimalPlaces {number}
function Math_Helper.round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)

  return math.floor(num * mult + 0.5) / mult
end

-- Converts given floating decimal value to fraction string
-- https://stackoverflow.com/questions/43565484/how-do-you-take-a-decimal-to-a-fraction-in-lua-with-no-added-libraries
-- @param num {float}  float value to convert
-- @param strLen {number}  Length of returned string
function Math_Helper.to_frac(num, strLen)
  -- TODO(frederick): need a more elegant way to check for infinity ("inf")
  if num == math.huge then
    return 0, 0, 0, 0
  end
    
  local integer = math.floor(num)
  local decimal = num - integer

  if decimal == 0 then 
    return num, 1.0, 0.0
  end

  local prec = 1000000000
  local gcd_ = gcd(Math_Helper.round(decimal * prec), prec)

  local numer = math.floor((integer * prec + Math_Helper.round(decimal * prec)) / gcd_)
  local denom = math.floor(prec / gcd_)
  local err = numer / denom - num
  local str = numer.."/"..denom

  if denom == 1.0 then
    str = numer
  end

  return str:sub(1, (strLen or 6)), numer, denom, err
end

-- Return denominator of a given number
-- @param num {float}  float value
function Math_Helper.get_denom(num)
  local s, n, d, e = Math_Helper.to_frac(num)
  
  return d
end

-- Return numerator of a given number
-- @param num {float}  float value
function Math_Helper.get_numer(num)
  local s, n, d, e = Math_Helper.to_frac(num)
  
  return n
end

return Math_Helper