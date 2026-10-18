--
-- B-B-B-B-Beat
-- 0.10.0
-- llllllll.co/t/35047
--
-- K2    Resync to beat 1
-- K3    See README
--
-- E1    Select page
-- E2-E3 Adjust page params
-- E4    BPM [Fates only]
-- P7-P12 FX & their LFOs
--
-- S-S-S-S-Stutter and
-- g-g-g-g-glitch till your
-- heart's content
--
-- See README for more details
-- See GUIDE for getting
-- started
--

--- constants
local VERSION = "0.10.0"

local BAR_VALS = {
  { str = "1/256", value = 1 / 256 }, -- [1]
  { str = "1/128", value = 1 / 128 }, -- [2]
  { str = "1/96", value = 1 / 96 },   -- [3]
  { str = "1/64", value = 1 / 64 },   -- [4]
  { str = "1/48", value = 1 / 48 },   -- [5]
  { str = "1/32", value = 1 / 32 },   -- [6]
  { str = "1/16", value = 1 / 16 },   -- [7]
  { str = "1/8", value = 1 / 8 },     -- [8]
  { str = "1/4", value = 1 / 4 },     -- [9]
  { str = "1/2", value = 1 / 2 },     -- [10]
  { str = "1", value = 1 },           -- [11]
  { str = "2", value = 2 },           -- [12]
  { str = "3", value = 3 },           -- [13]
  { str = "4", value = 4 },           -- [14]
}

-- Norns params menu doesn't like complicated objects for params:add_option
local BAR_VALS_STR = {}
for i = 1, #BAR_VALS do
  BAR_VALS_STR[i] = BAR_VALS[i].str
end

-- Gate lengths (Beat Repeat: Gate): 1/16 to 15/16, then 1 to 4 bars
local GATE_VALS = {}
for i = 1, 15 do
  GATE_VALS[i] = { str = i .. "/16", value = i / 16 }
end
for bars = 1, 4 do
  -- "bar" not "bars", longer strings overrun the next cell on screen
  GATE_VALS[15 + bars] = { str = bars .. " bar", value = bars }
end

local GATE_VALS_STR = {}
for i = 1, #GATE_VALS do
  GATE_VALS_STR[i] = GATE_VALS[i].str
end

-- Output modes (Beat Repeat: Mix, Insert, Gate) and their on-screen names,
-- first and last letters as on the feature-tape-in branch
local OUTPUT_MODES = {"mix", "insert", "gate"}
local OUTPUT_SHORT = {"MX", "IT", "GE"}
local OUTPUT_MIX = 1
local OUTPUT_INSERT = 2

-- Seconds the screen glitches for after an audible glitch
local GLITCH_UI_HOLD = 0.1

-- Max glitch speed change in octaves (+/-), at 100% intensity
local GLITCH_MAX_OCTAVES = 3

-- Index of BAR_VALS that triggers detail view (1 bar)
local BAR_VALS_DETAIL_RES = 11 

local fileselect = require 'fileselect'
local mathh = include("lib/math_helper")
local passthrough = include("lib/passthrough")
local ui = include("lib/core/ui")
local fx = include("lib/repeat_fx")

local grid = include("lib/core/grid")
grid.name = "Grid"
grid.index = 10 -- init/default: 1/2 note

local interval = include("lib/core/grid")
interval.name = "Interval"
interval.index = 12 -- init/default: 2 bars

--- Defaults
local beat_div = BAR_VALS[1].value --grid.index].value
local loop_len = 0
local tape_len = 0
local update_id
local redraw_metro
local chance_prev
local glitch_prev
local fx_id
local glitch_rate = {1, 1} -- per voice playback rate multiplier from glitch

--- States
local is_recording = true
local selecting_file = false
local is_repeating = false -- Chance fired on current grid step
local is_in_gate = true -- within Gate length of the last capture
local dry_level_prev
local glitch_ui_until = 0 -- util.time() the screen glitch ends
local loop_index -- index of BAR_VALS the Softcut loop is set to
local update_stutter = false
local is_stuttering = false
local update_variation = false
local update_glitch = false

--- Flips a given boolean bit... randomly.
-- @tparam param_pct {number}  param value (should generate value 0 - 100)
-- @tparam val {number}  the value to flip given boolean value
local function rand_occurrence(param_pct, val)
  local r = math.random()
  local bool_val = not val

  if (r < param_pct / 100) then
    bool_val = val
  end

  return bool_val
end

--- Sets loop length based on grid length and tempo.
-- @tparam index {number}  Optional index of BAR_VALS; default grid length
local function set_loop_len(index)
  loop_index = index or grid.index or 1
  if tape_len <= 0 then -- changing loop length of a loaded sample, stops the sample from playing
    loop_len = (BAR_VALS[loop_index].value / clock.get_tempo()) * 60
    for voice = 1, 2 do
      softcut.loop_end(voice, loop_len)
    end
  end
end

--- Returns index of a random length 1 to `max_halvings` halvings shorter
-- than given grid length, or given index when no shorter length exists.
-- Only exact halvings, so the shorter loop repeats evenly within a grid step.
-- @tparam index {number}  index of BAR_VALS
-- @tparam max_halvings {number}
local function vary_index(index, max_halvings)
  local options = {}
  for halvings = 1, max_halvings do
    local target = BAR_VALS[index].value / (2 ^ halvings)
    for i = 1, index - 1 do
      if math.abs(BAR_VALS[i].value - target) < 1e-9 then
        options[#options + 1] = i
      end
    end
  end

  if #options == 0 then
    return index
  end

  return options[math.random(#options)]
end

--- Returns true when repeats should be silent: in live mode between repeats
-- (Chance didn't fire), or during a glitch stutter.
local function is_wet_muted()
  return is_stuttering or (tape_len <= 0 and not is_repeating)
end

--- Returns true on the first clock tick at or after `pos`, measured from the
-- start of the interval. Clock ticks are 1/256 bar, so triplet lengths like
-- 1/96 never land on a tick exactly; this fires on the tick that passes them.
-- @tparam sum {number}  current position in bars, e.g. grid.sum
-- @tparam pos {number}  target position in bars
local function passes(sum, pos)
  local eps = 1e-9
  return sum >= pos - eps and sum - beat_div < pos - eps
end

--- Returns true on the first clock tick of each step of length `step`.
-- @tparam sum {number}  current position in bars, e.g. grid.sum
-- @tparam step {number}  step length in bars
local function is_step_start(sum, step)
  local eps = 1e-9
  return math.floor((sum + eps) / step) ~= math.floor((sum - beat_div + eps) / step)
end

--- Returns true while within `gate` bars of the capture at `offset`,
-- wrapping across the interval so a Gate longer than it never closes.
-- @tparam sum {number}  current position in bars, e.g. grid.sum
-- @tparam offset {number}  capture start in bars
-- @tparam interval_len {number}  in bars
-- @tparam gate {number}  in bars
local function within_gate(sum, offset, interval_len, gate)
  return (sum - offset) % interval_len < gate - 1e-9
end

--- Sets dry (monitor) level from "mix" and "output" params.
-- Mix mode always passes the input, Insert mutes it while repeats play and
-- Gate never passes it. Changes go through the mixer's own level smoothing.
local function apply_dry()
  local output = params:get("output")
  local is_on = output == OUTPUT_MIX or (output == OUTPUT_INSERT and not is_repeating)
  local level = is_on and math.min(1, 2 * (1 - params:get("mix") / 100)) or 0

  if level ~= dry_level_prev then
    audio.level_monitor(level)
    dry_level_prev = level
  end
end

--- Returns random playback rate multiplier for a glitch.
-- Spread widens with intensity, up to GLITCH_MAX_OCTAVES either way, and
-- the chance of playing backwards rises to 50%.
-- @tparam intensity {number}  0 - 1
local function glitch_speed(intensity)
  local speed = 2 ^ (mathh.random(-1, 1) * GLITCH_MAX_OCTAVES * intensity)

  if math.random() < intensity / 2 then
    speed = -speed
  end

  return speed
end

--- Starts recording into Softcut.
local function start_rec()
  if tape_len <= 0 then
    is_recording = true
    softcut.buffer_clear()
  end
  fx.reset_repeats()

  for voice = 1, 2 do
    softcut.position(voice, 1)
    softcut.rec_level(voice, 1)
  end
end

--- Stops recording into softcut.
local function stop_rec()
  is_recording = false

  for voice = 1, 2 do
    softcut.rec_level(voice, 0)
  end
end

--- Handler for clock update sync, fires at `beat_div` interval.
local function update()
  while true do
    clock.sync(beat_div * 4)

    -- randomize occurrence booleans
    update_stutter = rand_occurrence(params:get("glitch"), true)
    update_glitch = rand_occurrence(params:get("glitch"), true)

    -- record incoming audio
    local offset_val = (params:get("offset") / 16)
    if (grid.sum == offset_val or grid.sum >= BAR_VALS[interval.get()].value) then
      start_rec()
    elseif passes(grid.sum, offset_val + BAR_VALS[grid.index].value) then
      stop_rec()
    end

    -- bang on beat as set by grid length
    if is_step_start(grid.sum, BAR_VALS[grid.index].value) then
      grid.increment_pos(1)
      glitch_rate = {1, 1}

      -- rolled once per step so on-screen signals hold for the whole step
      local vari = params:get("variation")
      update_variation = vari > 0 and rand_occurrence(vari * 10, true)
      local update_chance = rand_occurrence(params:get("chance"), true)

      -- variation: shorter loop for this step only, higher values shrink more
      local index = grid.index
      if update_variation then
        index = vary_index(index, math.ceil(vari / 3))
      end
      if index ~= loop_index then
        set_loop_len(index)
      end

      -- chance, within gate
      is_in_gate = within_gate(grid.sum, offset_val,
        BAR_VALS[interval.get()].value, GATE_VALS[params:get("gate")].value)
      is_repeating = update_chance and is_in_gate and not is_recording
      if is_repeating then
        -- count only repeats that fire, otherwise decay runs down on grid
        -- steps Chance skipped and repeats are near silent when they play
        fx.increment_repeats()
        for voice = 1, 2 do
          softcut.play(voice, 1)
          softcut.position(voice, 1)
        end
      end
      apply_dry()

      is_stuttering = (params:get("glitch_stutter") == 1 and update_stutter)
      fx.apply_level(is_wet_muted(), true)

      update_stutter = false
    end

    -- glitch: jump each voice to a random point, sometimes changing speed
    -- until the next grid step
    if update_glitch and not is_recording then
      if not is_wet_muted() then
        -- hold long enough for the 30 fps screen to show what's heard
        glitch_ui_until = util.time() + GLITCH_UI_HOLD
      end
      local intensity = params:get("glitch_intensity") / 100
      for voice = 1, 2 do
        softcut.play(voice, 1)
        softcut.position(voice, (math.random() * loop_len))
        if math.random() < intensity then
          glitch_rate[voice] = glitch_speed(intensity)
        end
      end
    end
    fx.apply_rate(is_recording, glitch_rate)

    grid.increment_sum(beat_div)

    if (grid.sum >= BAR_VALS[interval.get()].value) then
      grid.reset_sum()
    end
  end
end

--- Handler for repeat FX, applies LFO movement between clock ticks.
local function update_fx()
  while true do
    clock.sleep(1 / 30)
    fx.apply_rate(is_recording, glitch_rate)
    fx.apply_level(is_wet_muted())
    fx.apply_filter()
  end
end

--- Handler for metro thread, e.g. screen redrawing.
local function update_metro(count)
  if selecting_file == false then
    redraw()
  end
end

--- Handler when "grid" parameter is set.
function grid.update(val)
  grid.index = mathh.clamp(val, 1, interval.index)

  if (val > interval.index) then
    grid.set(grid.index)
    return
  end

  beat_div = BAR_VALS[1].value
  set_loop_len()
end

--- Handler when "interval" parameter is set.
function interval.update(val)
  interval.index = mathh.clamp(val, 5, #BAR_VALS) -- 6, #BAR_VALS)

  if (interval.index < grid.index) then
    grid.set(interval.index)
  end
end

--- Sets wet (Softcut) and dry (monitor) levels from "mix" param.
-- Both are at unity at 50%, so the midpoint matches the unmixed signal.
local function apply_mix()
  audio.level_cut(math.min(1, 2 * params:get("mix") / 100))
  apply_dry()
end

--- Routes ADC channels into Softcut voices from "input" param.
-- Mono feeds input 1 to both voices so repeats play on both sides.
local function apply_input()
  local is_mono = params:get("input") == 2
  for voice = 1, 2 do
    softcut.level_input_cut(1, voice, (is_mono or voice == 1) and 1 or 0)
    softcut.level_input_cut(2, voice, (not is_mono and voice == 2) and 1 or 0)
  end
end

--- Routes input into Softcut, overriding system mixer (restored on cleanup).
-- Must run after `params:bang()`, which re-applies stored mixer levels and
-- would otherwise silence Softcut's input if "input adc" is at -inf.
-- Input stays at unity, output modes mute the dry signal at the monitor so
-- capturing is never muted.
local function init_audio()
  dry_level_prev = nil
  audio.level_adc(1) -- input volume 1
  audio.level_adc_cut(1) -- ADC to Softcut input
  audio.level_cut_rev(0) -- Softcut reverb send 0
  apply_mix()
  apply_input()
end

--- Init Softcut.
local function init_softcut()
  if tape_len <= 0 then
    softcut.buffer_clear() -- clear Softcut buffer
  end

  for voice = 1, 2 do
    softcut.enable(voice, 1) -- enable voice 1
    softcut.buffer(voice, voice)
    softcut.level(voice, 1) -- Softcut voice 1 output level
    softcut.pan(voice, voice == 1 and -1 or 1)
    softcut.rate(voice, 1)

    softcut.loop(voice, 1) -- voice 1 enable loop
    softcut.loop_start(voice, 0) -- voice 1 loop start @ 0.0s
    if tape_len <= 0 then
      set_loop_len()
    end

    softcut.position(voice, 1) -- voice 1 loop position @ 0.0s
    softcut.pre_level(voice, 1) -- voice 1 overdub level
    softcut.rec_level(voice, 1) -- voice 1 record level
    softcut.rec(voice, 1) -- voice 1 enable record
  end

  for voice = 1, 2 do
    softcut.play(voice, 1) -- voice 1 enable playback
  end
end

--- Init Midi.
-- TODO(frederickk): Add ability to repeat Midi input with Midi output.
local function init_midi()
  passthrough.init()
end

--- Event handler for Midi start.
function clock.transport.start()
  grid.reset_sum() 
end

--- Event handler for Midi stop.
function clock.transport.stop()
  grid.reset_sum() 
end

--- Handler when clock tempo changes (internal, MIDI, Link or crow).
function clock.tempo_change_handler(tempo)
  set_loop_len()
end

--- Init Metro.
local function init_metro()
  redraw_metro = metro.init(update_metro, 1 / 30, -1) -- 30 fps screen refresh
  if redraw_metro then
    redraw_metro:start()
  else
    print("b-b-b-b-beat: no free metros for screen redraw")
  end
end

--- Handler for loading sample into softcut.
-- @tparam {string}  path to sound file
local function load_file(file)
  selecting_file = false

  if file ~= nil and file ~= "cancel" and file ~= "-" and params:get("mode") == 2 then
    local ch, samples = audio.file_info(file)
    if ch == nil or ch < 1 or samples == nil or samples <= 0 then
      print("b-b-b-b-beat: unable to read " .. file)
      return
    end

    is_recording = false
    -- Softcut copies frames into its 48 kHz buffer without resampling, so
    -- buffer length is frames / 48000 whatever the file's own rate
    tape_len = samples / 48000

    grid.reset_sum()
    softcut.buffer_clear()
    if ch == 1 then
      softcut.buffer_read_mono(file, 0, 1, -1, 1, 1)
      softcut.buffer_read_mono(file, 0, 1, -1, 1, 2)
    else
      softcut.buffer_read_stereo(file, 0, 1, -1)
    end
    init_softcut()

    for voice = 1, 2 do
      softcut.loop_end(voice, tape_len)
    end
    
    loop_len = tape_len
  end
end

--- Init/add params.
local function init_params()
  local function pct(param) return param:get() .. "%" end

  ui.add_page_params()

  params:add_option("mode", "Mode", {"live", "sample"}, 1)
  params:set_action("mode", function(val)
      if val == 1 then
        selecting_file = false
        tape_len = 0
        grid.reset_sum()
        set_loop_len()
      elseif val == 2 then
        if params:get("sample") ~= "-" and params:get("sample") ~= nil then
          load_file(params:get("sample"))
        end
      end
    end)

  -- load file into Softcut
  -- https://llllllll.co/t/norns-2-0-softcut/20550/121
  -- https://github.com/monome/softcut-studies/blob/master/7-files.lua
  params:add_file("sample", "Audio file")
  params:set_action("sample", load_file)

  params:add_option("input", "Input", {"stereo", "mono"}, 1)
  params:set_action("input", apply_input)

  -- dry/wet balance, 50% leaves both at unity
  params:add_number("mix", "Mix", 0, 100, 50, pct)
  params:set_action("mix", apply_mix)

  -- when the dry input plays (Beat Repeat: Mix, Insert, Gate)
  params:add_option("output", "Output", OUTPUT_MODES, OUTPUT_INSERT)
  params:set_action("output", apply_dry)

  params:add_separator("repeat_separator", "Repeat")

  -- loop duration (Beat Repeat: interval)
  interval.add_params(BAR_VALS_STR, interval.index)

  -- clock division (Beat Repeat: grid)
  grid.add_params(BAR_VALS_STR, grid.index)

  -- prabability of repeat happening (e.g. softcut or passthrough) (Beat Repeat: chance)
  params:add_number("chance", "Chance", 0, 100, 100, pct)
  params:set_action("chance", function(val)
      if (val <= 0) then
        update_stutter = false
      end
    end)

  -- offset starting position (by 1/16th notes) of record start (Beat Repeat: offset)
  params:add_number("offset", "Offset", 0, 15, 0,
    function(param) return param:get() .. "/16" end)

  -- total length of repeats from capture (Beat Repeat: gate), max by default
  params:add_option("gate", "Gate", GATE_VALS_STR, #GATE_VALS)

  -- variation of clock division length (Beat Repeat: variation)
  params:add_number("variation", "Variation", 0, 10, 0)

  -- glitch frequency: chance per clock tick of a glitch, and per step of stutter
  params:add_number("glitch", "Glitch", 0, 100, 0, pct)
  params:set_action("glitch", function(val)
      if (val <= 0) then
        update_glitch = false
      end
    end)

  -- glitch intensity: chance and range of speed changes, UI shake amount
  params:add_number("glitch_intensity", "Intensity", 0, 100, 50, pct)

  -- glitchy params
  params:add_option("glitch_ui", "Glitch UI", {"yes", "no"}, 1)
  params:add_option("glitch_stutter", "Glitch stutter", {"yes", "no"}, 2)

  -- pitch, volume and filter of repeats (Beat Repeat: Pitch, Volume, Filter)
  fx.add_params(BAR_VALS, BAR_VALS_DETAIL_RES)

  -- trigger param defaults
  params:bang()

  -- load saved params
  params:read()
end 

--- I-I-I-I-Init.
function init()
  print("b-b-b-b-beat v" .. VERSION)

  init_midi()
  init_softcut()
  init_params()
  init_audio()
  init_metro()
  fx.init_softcut()

  update_id = clock.run(update)
  fx_id = clock.run(update_fx)

  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
end

--- Returns display string for repeat FX param, compact enough for a cell.
-- @tparam id {string}  param id
local function fx_str(id)
  local val = params:get(id)

  if id == "pitch" then
    return string.format("%+dst", val)
  elseif id == "pitch_decay" then
    return string.format("%+.2f", val)
  elseif id == "filter_freq" then
    return fx.format_freq(val)
  elseif string.find(id, "_lfo_rate$") then
    return BAR_VALS[val].str
  elseif id == "pitch_lfo_depth" or id == "filter_lfo_depth" then
    return string.format("%.2f", val)
  end

  return util.round(val) .. "%"
end

--- Returns true while given FX's LFO is on and in its upper half.
-- @tparam target {string}  "pitch", "volume" or "filter"
local function lfo_signal(target)
  return function()
    return params:get(target .. "_lfo_depth") > 0 and fx.lfo[target].value > 0
  end
end

-- E2/E3 params of each page (P0 is BPM on 3 encoder devices). `format`
-- overrides the param's own string, `signal` returns state for a dot.
local PAGES = {
  [1] = { {id = "interval"}, {id = "grid"} },
  [2] = {
    {id = "offset", label = "Offset"},
    {id = "gate", label = "Gate", signal = function() return is_in_gate end}
  },
  [3] = {
    {id = "chance", label = "Chance", signal = function() return is_repeating end},
    {id = "variation", label = "Variation", signal = function() return update_variation end}
  },
  [4] = {
    {id = "glitch", label = "Glitch", signal = function() return util.time() < glitch_ui_until end},
    {id = "glitch_intensity", label = "Intensity"}
  },
  [5] = { {id = "output", label = "Output"}, {id = "mix", label = "Mix"} },
  [6] = { {id = "mode", label = "Mode"}, {id = "input", label = "Input"} },
  [7] = { {id = "pitch", label = "Pitch", format = fx_str},
    {id = "pitch_decay", label = "Decay", format = fx_str} },
  [8] = { {id = "pitch_lfo_rate", label = "Rate", format = fx_str, signal = lfo_signal("pitch")},
    {id = "pitch_lfo_depth", label = "Depth", format = fx_str} },
  [9] = { {id = "volume", label = "Volume", format = fx_str},
    {id = "volume_decay", label = "Decay", format = fx_str} },
  [10] = { {id = "volume_lfo_rate", label = "Rate", format = fx_str, signal = lfo_signal("volume")},
    {id = "volume_lfo_depth", label = "Depth", format = fx_str} },
  [11] = {
    {id = "filter_freq", label = "Freq", format = fx_str,
      signal = function() return params:get("filter") == 2 end},
    {id = "filter_width", label = "Width", format = fx_str}
  },
  [12] = { {id = "filter_lfo_rate", label = "Rate", format = fx_str, signal = lfo_signal("filter")},
    {id = "filter_lfo_depth", label = "Depth", format = fx_str} },
}

-- Pages sharing a screen row; P0 and P1 show the first row
local ROWS = { {2, 3}, {4, 5}, {6}, {7, 8}, {9, 10}, {11, 12} }

local CHANCE_PAGE = 3
local GLITCH_PAGE = 4
local OUTPUT_PAGE = 5
local MODE_PAGE = 6

--- Encoder input.
-- @tparam index {number}  which encoder
-- @tparam delta {number}  amount of change/turn
function enc(index, delta)
  local page = ui.page_get()

  if index == 1 then
    ui.page_delta(delta)
  elseif index == 4 and ui.HAS_E4 then
    -- Fates only; persistent BPM adjustment
    params:delta("clock_tempo", delta)
  elseif page == 0 and index == 2 then
    -- Norns; BPM only on page 0
    params:delta("clock_tempo", delta)
  elseif PAGES[page] and (index == 2 or index == 3) then
    params:delta(PAGES[page][index - 1].id, delta)
  end

  redraw()
end

--- Key/button input.
-- @tparam index {number}  which button
-- @tparam state {boolean|number}  button pressed
function key(index, state)
  if index == 2 and state == 1 then
    grid.reset_sum()
  elseif index == 3 and state == 1 then
    if params:get("page") == CHANCE_PAGE then
      chance_prev = params:get("chance")
      params:set("chance", 0)
    elseif params:get("page") == GLITCH_PAGE then
      glitch_prev = params:get("glitch")
      params:set("glitch", 100)
    elseif params:get("page") == MODE_PAGE and params:get("mode") == 2 then
      selecting_file = true
      fileselect.enter(_path.audio, function(file)
        selecting_file = false
        if file ~= "cancel" then
          params:set("sample", file) -- triggers load_file and saves with PSET
        end
      end)
    end
  elseif index == 3 and state == 0 then
    -- restore regardless of page, K3 may have been pressed before E1 changed it
    if chance_prev ~= nil then
      params:set("chance", chance_prev)
      chance_prev = nil
    end
    if glitch_prev ~= nil then
      params:set("glitch", glitch_prev)
      glitch_prev = nil
    end
  end
end

--- Returns true when the UI glitch effect should be drawn.
local function is_ui_glitching()
  return (params:get("glitch_ui") == 1) and util.time() < glitch_ui_until
end

--- Returns multiplier for shifting UI, scaled by glitch intensity.
local function glitch_shift_px()
  if is_ui_glitching() then
    local glitch_val = math.random() * ((params:get("glitch_intensity") / 1000))

    return (1 + (mathh.random(-1, 1) * glitch_val))
  end

  return 1
end
ui.glitch_func = glitch_shift_px

--- Displays string for BAR_VAL selected.
-- @tparam index {number}  index of length value 
-- @tparam str {number}  prefix
local function str_note_bar(index, str)
  if index < BAR_VALS_DETAIL_RES then return (str or "") .. " Note"
  elseif index == BAR_VALS_DETAIL_RES then return (str or "") .. " Bar"
  else return (str or "") .. " Bars" end
end

--- Returns cells of the row holding given page.
-- @tparam page {number}
local function row_cells(page)
  local row = ROWS[1]
  for _, r in ipairs(ROWS) do
    for _, p in ipairs(r) do
      if p == page then row = r end
    end
  end

  local cells = {}
  for _, p in ipairs(row) do
    for _, spec in ipairs(PAGES[p]) do
      cells[#cells + 1] = {
        label = spec.label,
        value = spec.format and spec.format(spec.id) or params:string(spec.id),
        page = p,
        signal = spec.signal and spec.signal() or nil
      }
    end
  end

  return cells
end

--- Handler for screen redraw.
function redraw()
  -- skipping clear while glitching leaves trails on screen
  if not is_ui_glitching() then
    screen.clear()
  end

  screen.level(ui.ON)
  ui.page_marker(15, 10, ui.page_get())

  -- swings once per bar, independent of grid length
  ui.draw_tempo(clock.get_tempo(), math.floor(clock.get_beats() / 4) % 2 == 0, ui.HAS_E4)

  local y = ui.draw_bars({
    interval = interval,
    grid = grid,
    y = 24,
    interval_len = BAR_VALS[interval.get()].value,
    grid_len = BAR_VALS[grid.index].value,
    offset = params:get("offset") / 16,
    gate = GATE_VALS[params:get("gate")].value,
    pos = grid.pos,
    is_detail = interval.get() <= BAR_VALS_DETAIL_RES,
    is_repeating = is_repeating,
    interval_label = str_note_bar(interval.get(), BAR_VALS[interval.get()].str),
    grid_label = str_note_bar(grid.get(), BAR_VALS[grid.index].str),
    pages = {interval = 1, gate = 2}
  })
  ui.draw_row(row_cells(ui.page_get()), y + 8)

  ui.draw_mode({
    is_live = params:get("mode") == 1,
    is_recording = is_recording,
    has_sample = params:get("sample") ~= "-" and params:get("sample") ~= nil,
    output = OUTPUT_SHORT[params:get("output")],
    output_page = OUTPUT_PAGE
  })

  screen.update()
end

--- Restores system mixer params this script changes directly via `audio`.
local function restore_mixer()
  for _, id in ipairs({"input_level", "monitor_level", "softcut_level", "rev_cut_input", "cut_input_adc"}) do
    if params.lookup[id] then
      params:lookup_param(id):bang()
    end
  end
end

--- Writes params and restores mixer on script end.
function cleanup()
  if redraw_metro then
    redraw_metro:stop()
  end
  params:write(norns.state.pset_last)
  restore_mixer()
end
