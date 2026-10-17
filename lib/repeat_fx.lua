--- Repeat FX: pitch, volume and filter applied to repeats (Softcut voices),
-- each modulated by per-repeat decay and a tempo-synced LFO.
local controlspec = require 'controlspec'
local mod = include("lib/modulation")

local RepeatFx = {
  --- Max pitch shift in semitones (+/-).
  PITCH_RANGE = 24,
  --- Number of params added by `add_params`.
  PARAM_COUNT = 16,
  --- Repeats since last capture; drives decay and "rand/rpt" LFO shape.
  repeat_n = 0,
  --- True while K3 is held on an FX page, encoders then edit the LFO.
  shift = false,
  --- LFOs per FX target.
  lfo = {
    pitch = mod.new_lfo(),
    volume = mod.new_lfo(),
    filter = mod.new_lfo()
  }
}

local FILTER_MIN_HZ = 20
local FILTER_MAX_HZ = 20000
local FILTER_RQ_MIN = 0.05
local FILTER_RQ_MAX = 4
local SLEW_TIME = 1 / 30 -- matches FX update rate, smooths LFO steps
local GLITCH_SLEW_TIME = 0.001 -- Softcut default

local rate_vals = {}
local rate_slew_prev = {}
local filter_on_prev

--- Creates controlspec where one encoder detent moves by `step`.
local function spec(min, max, warp, step, default, units)
  return controlspec.new(min, max, warp, step, default, units, step / (max - min))
end

--- Adds LFO rate, shape and depth params for given target.
local function add_lfo_params(target, rate_options, default_rate, depth_spec)
  params:add_option(target .. "_lfo_rate", "LFO rate", rate_options, default_rate)
  params:add_option(target .. "_lfo_shape", "LFO shape", mod.SHAPES, 1)
  params:add_control(target .. "_lfo_depth", "LFO depth", depth_spec)
end

--- Add params for repeat FX.
-- @tparam bar_vals {array}  tempo division table; each entry has `str` and `value` (in bars)
-- @tparam default_rate {number}  index of bar_vals for default LFO rate
function RepeatFx.add_params(bar_vals, default_rate)
  local rate_options = {}
  for i = 1, #bar_vals do
    rate_options[i] = bar_vals[i].str
    rate_vals[i] = bar_vals[i].value
  end

  params:add_group("repeat_fx", "REPEAT FX", RepeatFx.PARAM_COUNT)

  -- pitch (Beat Repeat: Pitch, Pitch Decay)
  params:add_number("pitch", "Pitch", -RepeatFx.PITCH_RANGE, RepeatFx.PITCH_RANGE, 0,
    function(param) return string.format("%+dst", param:get()) end)
  params:add_control("pitch_decay", "Pitch decay", spec(-12, 12, 'lin', 0.25, 0, "st"))
  add_lfo_params("pitch", rate_options, default_rate, spec(0, RepeatFx.PITCH_RANGE, 'lin', 0.25, 0, "st"))

  -- volume (Beat Repeat: Volume, Decay)
  params:add_number("volume", "Volume", 0, 100, 100)
  params:add_number("volume_decay", "Volume decay", 0, 100, 0)
  add_lfo_params("volume", rate_options, default_rate, spec(0, 100, 'lin', 1, 0, "%"))

  -- filter (Beat Repeat: Filter on/off, Frequency, Width)
  params:add_option("filter", "Filter", {"off", "on"}, 1)
  params:add_control("filter_freq", "Filter freq", controlspec.new(FILTER_MIN_HZ, FILTER_MAX_HZ, 'exp', 0, 1000, "Hz"))
  params:add_number("filter_width", "Filter width", 1, 100, 50)
  add_lfo_params("filter", rate_options, default_rate, spec(0, 4, 'lin', 0.05, 0, "oct"))
end

--- Updates and returns LFO value for given target, scaled by -1 - 1.
-- Returns 0 when LFO depth is 0.
-- @tparam target {string}  "pitch", "volume" or "filter"
-- @tparam beats {number}  current clock position in beats
local function lfo_value(target, beats)
  local lfo = RepeatFx.lfo[target]
  if params:get(target .. "_lfo_depth") <= 0 then
    lfo.value = 0
    return 0
  end

  local period = rate_vals[params:get(target .. "_lfo_rate")] * 4
  return lfo:update(params:get(target .. "_lfo_shape"), beats, period, RepeatFx.repeat_n)
end

--- Returns current pitch in semitones.
-- @tparam beats {number}  current clock position in beats
function RepeatFx.pitch(beats)
  local st = mod.decay_linear(params:get("pitch"), params:get("pitch_decay"), RepeatFx.repeat_n)
  st = st + lfo_value("pitch", beats) * params:get("pitch_lfo_depth")

  return util.clamp(st, -RepeatFx.PITCH_RANGE, RepeatFx.PITCH_RANGE)
end

--- Returns current volume as linear amplitude (0 - 1).
-- @tparam beats {number}  current clock position in beats
function RepeatFx.volume(beats)
  local amp = mod.decay_exp(params:get("volume") / 100, params:get("volume_decay"), RepeatFx.repeat_n)
  -- tremolo: LFO at +1 leaves volume as is, at -1 reduces it by depth
  local depth = params:get("volume_lfo_depth") / 100
  amp = amp * (1 - (depth * (1 - lfo_value("volume", beats)) / 2))

  return util.clamp(amp, 0, 1)
end

--- Returns current filter frequency in Hz.
-- @tparam beats {number}  current clock position in beats
function RepeatFx.filter_freq(beats)
  local octaves = lfo_value("filter", beats) * params:get("filter_lfo_depth")

  return util.clamp(params:get("filter_freq") * (2 ^ octaves), FILTER_MIN_HZ, FILTER_MAX_HZ)
end

--- Returns filter reciprocal Q for current width (1 - 100%).
function RepeatFx.filter_rq()
  local width = (params:get("filter_width") - 1) / 99

  return FILTER_RQ_MIN * ((FILTER_RQ_MAX / FILTER_RQ_MIN) ^ width)
end

--- Init Softcut slew for FX.
function RepeatFx.init_softcut()
  for voice = 1, 2 do
    softcut.level_slew_time(voice, SLEW_TIME)
    softcut.rate_slew_time(voice, SLEW_TIME)
    rate_slew_prev[voice] = SLEW_TIME
  end
  RepeatFx.apply_filter(true)
end

--- Resets repeat count, e.g. on new capture.
function RepeatFx.reset_repeats()
  RepeatFx.repeat_n = 0
end

--- Counts a repeat.
function RepeatFx.increment_repeats()
  RepeatFx.repeat_n = RepeatFx.repeat_n + 1
end

--- Sets Softcut playback rate from pitch.
-- Recording always runs at rate 1, otherwise captured audio is warped.
-- @tparam is_recording {boolean}
-- @tparam rate_mult {array}  per voice rate multiplier, e.g. from glitch
function RepeatFx.apply_rate(is_recording, rate_mult)
  local rate = 1
  if not is_recording then
    rate = 2 ^ (RepeatFx.pitch(clock.get_beats()) / 12)
  end

  for voice = 1, 2 do
    -- keep glitch rate jumps abrupt, smooth everything else
    local slew = (rate_mult[voice] ~= 1) and GLITCH_SLEW_TIME or SLEW_TIME
    if slew ~= rate_slew_prev[voice] then
      softcut.rate_slew_time(voice, slew)
      rate_slew_prev[voice] = slew
    end
    softcut.rate(voice, is_recording and 1 or (rate * rate_mult[voice]))
  end
end

--- Sets Softcut voice level from volume.
-- @tparam is_muted {boolean}  e.g. glitch stutter
function RepeatFx.apply_level(is_muted)
  local level = is_muted and 0 or RepeatFx.volume(clock.get_beats())

  for voice = 1, 2 do
    softcut.level(voice, level)
  end
end

--- Sets Softcut post-filter (band-pass) from filter params.
-- @tparam force {boolean}  re-send filter routing even if unchanged
function RepeatFx.apply_filter(force)
  local is_on = params:get("filter") == 2
  local route = force or (is_on ~= filter_on_prev)
  filter_on_prev = is_on

  for voice = 1, 2 do
    if route then
      softcut.post_filter_lp(voice, 0)
      softcut.post_filter_hp(voice, 0)
      softcut.post_filter_br(voice, 0)
      softcut.post_filter_dry(voice, is_on and 0 or 1)
      softcut.post_filter_bp(voice, is_on and 1 or 0)
    end
    if is_on then
      softcut.post_filter_fc(voice, RepeatFx.filter_freq(clock.get_beats()))
      softcut.post_filter_rq(voice, RepeatFx.filter_rq())
    end
  end
end

--- Returns display string for a filter frequency.
-- @tparam hz {number}
function RepeatFx.format_freq(hz)
  if hz >= 1000 then
    return string.format("%.1fk", hz / 1000)
  end

  return string.format("%d", math.floor(hz + 0.5))
end

return RepeatFx
