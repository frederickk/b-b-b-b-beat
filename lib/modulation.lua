--- Modulation sources for repeat FX.
-- Tempo-synced LFO with a per-repeat random shape, plus per-repeat decay.
local Modulation = {
  --- LFO shape names; index is stored in params.
  SHAPES = {"sine", "triangle", "saw", "square", "s&h", "rand/rpt"}
}

local SINE = 1
local TRIANGLE = 2
local SAW = 3
local SQUARE = 4
local SAMPLE_HOLD = 5
local RANDOM_REPEAT = 6

local Lfo = {}
Lfo.__index = Lfo

--- Creates new LFO.
-- @tparam random_func {function}  Optional random source returning 0 - 1; default math.random
function Modulation.new_lfo(random_func)
  return setmetatable({
    random = random_func or math.random,
    cycle = nil,
    held = 0,
    repeat_n = nil,
    repeat_val = 0,
    value = 0
  }, Lfo)
end

--- Returns random value between -1 and 1.
function Lfo:bipolar_random()
  return (self.random() * 2) - 1
end

--- Calculates LFO value between -1 and 1, also stored as `self.value`.
-- @tparam shape {number}  index of SHAPES
-- @tparam beats {number}  current clock position in beats
-- @tparam period {number}  length of one LFO cycle in beats
-- @tparam repeat_n {number}  current repeat count; used by "rand/rpt" shape
function Lfo:update(shape, beats, period, repeat_n)
  local pos = beats / period
  local phase = pos - math.floor(pos)

  if shape == SINE then
    self.value = math.sin(phase * 2 * math.pi)
  elseif shape == TRIANGLE then
    self.value = 1 - (4 * math.abs(phase - 0.5))
  elseif shape == SAW then
    self.value = (2 * phase) - 1
  elseif shape == SQUARE then
    self.value = phase < 0.5 and 1 or -1
  elseif shape == SAMPLE_HOLD then
    -- new random value once per LFO cycle
    local cycle = math.floor(pos)
    if cycle ~= self.cycle then
      self.cycle = cycle
      self.held = self:bipolar_random()
    end
    self.value = self.held
  elseif shape == RANDOM_REPEAT then
    -- new random value once per repeat, ignores LFO rate
    if repeat_n ~= self.repeat_n then
      self.repeat_n = repeat_n
      self.repeat_val = self:bipolar_random()
    end
    self.value = self.repeat_val
  else
    self.value = 0
  end

  return self.value
end

--- Applies additive decay, e.g. semitones per repeat.
-- @tparam base {number}  starting value
-- @tparam amount {number}  change per repeat
-- @tparam repeat_n {number}  repeats since capture
function Modulation.decay_linear(base, amount, repeat_n)
  return base + (amount * repeat_n)
end

--- Applies multiplicative decay, e.g. level lost per repeat.
-- @tparam base {number}  starting value
-- @tparam pct {number}  percent lost per repeat (0 - 100)
-- @tparam repeat_n {number}  repeats since capture
function Modulation.decay_exp(base, pct, repeat_n)
  return base * ((1 - (pct / 100)) ^ repeat_n)
end

return Modulation
