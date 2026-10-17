--
-- B-B-B-B-Beat
-- 0.10.0
-- llllllll.co/t/35047
--
-- K2    Resync to beat 1
-- K3    See README
--
-- E1    Cycle through params
-- E4    BPM [Fates only]
-- E2-E3 Adjust highlight params
-- K3    (hold) P5-P7 LFO
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
  { str = "1/256", value = 1 / 256, ppq = 64 },  -- [1]
  { str = "1/128", value = 1 / 128, ppq = 32 },  -- [2]
  { str = "1/96", value = 1 / 96, ppq = 24 },    -- [3]
  { str = "1/64", value = 1 / 64, ppq = 16 },    -- [4]
  { str = "1/48", value = 1 / 48, ppq = 12 },    -- [5]
  { str = "1/32", value = 1 / 32, ppq = 8 },     -- [6] *
  { str = "1/16", value = 1 / 16, ppq = 4 },     -- [7]
  { str = "1/8", value = 1 / 8, ppq = 2 },       -- [8]
  { str = "1/4", value = 1 / 4, ppq = 1 },       -- [9]
  { str = "1/2", value = 1 / 2, ppq = 0.5 },     -- [10]
  { str = "1", value = 1, ppq = 0.25 },          -- [11]
  { str = "2", value = 2, ppq = 0.125 },         -- [12]
  { str = "3", value = 3, ppq = 0.083 },         -- [13]
  { str = "4", value = 4, ppq = 0.0625 },        -- [14]
}

-- Norns params menu doesn't like complicated objects for params:add_option
local BAR_VALS_STR = {}
for i = 1, #BAR_VALS do
  BAR_VALS_STR[i] = BAR_VALS[i].str
end

-- Index of BAR_VALS that triggers detail view (1 bar)
local BAR_VALS_DETAIL_RES = 11 

-- Repeat FX pages; E2/E3 edit `main`/`second`, or LFO rate/depth while K3 held
local FX_PAGES = {
  [5] = { target = "pitch", main = "pitch", second = "pitch_decay",
    labels = {"Pitch", "Decay"} },
  [6] = { target = "volume", main = "volume", second = "volume_decay",
    labels = {"Volume", "Decay"} },
  [7] = { target = "filter", main = "filter_freq", second = "filter_width",
    labels = {"Freq", "Width"} },
}


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
local grid_index_prev
local chance_prev
local glitch_prev
local fx_id
local glitch_rate = {1, 1} -- per voice playback rate multiplier from glitch

--- States
local is_recording = true
local selecting_file = false
local update_tempo = true
local update_chance = false
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
local function set_loop_len()
  if tape_len <= 0 then -- changing loop length of a loaded sample, stops the sample from playing
    loop_len = (BAR_VALS[(grid.index or 1)].value / clock.get_tempo()) * 60
    for voice = 1, 2 do
      softcut.loop_end(voice, loop_len)
    end
  end 
end

--- Starts recording into Softcut.
local function start_rec()
  audio.level_adc(1)

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
  audio.level_adc(0)

  for voice = 1, 2 do
    softcut.rec_level(voice, 0)
  end
end

--- Handler for clock update sync, fires at `beat_div` interval.
local function update()
  while true do
    clock.sync(beat_div * 4)

    -- randomize occurrence booleans
    update_chance = rand_occurrence(params:get("chance"), true)
    update_stutter = rand_occurrence(params:get("glitch"), true)
    if (params:get("variation") > 0) then
      update_variation = rand_occurrence(params:get("variation") * 10, true)
    end
    update_glitch = rand_occurrence(params:get("glitch"), true)

    grid_index_prev = grid.index

    -- record incoming audio
    local offset_val = (params:get("offset") / 16)
    if (grid.sum == offset_val or grid.sum >= BAR_VALS[interval.get()].value) then
      start_rec()
    elseif (grid.sum - offset_val == BAR_VALS[grid.index].value) then
      stop_rec()
    end

    -- bang on beat as set by grid length
    if ((grid.sum * (BAR_VALS[1].ppq * 4)) % math.floor(BAR_VALS[1].ppq / BAR_VALS[grid.index].ppq)) == 0 then
      update_tempo = not update_tempo
      grid.increment_pos(1)
      if not is_recording then
        fx.increment_repeats()
      end

      -- variation
      if update_variation then
        local vari = params:get("variation")
        local vari_rand = mathh.random_int(-vari - 1, vari)
      
        grid.index = util.clamp(grid.index * vari_rand, 1, grid_index_prev)
        set_loop_len()

        for voice = 1, 2 do
          softcut.position(voice, 1)
        end
      end

      -- chance
      if update_chance and not is_recording then
        for voice = 1, 2 do
          softcut.play(voice, 1)
          softcut.position(voice, 1)
        end
        audio.level_adc(0)
      else
        if tape_len <= 0 then -- when playing a sample, just let it play when repeat not triggered
          for voice = 1, 2 do
            -- softcut.play(voice, 0)
          end
        end
        audio.level_adc(1)
      end

      is_stuttering = (params:get("glitch_stutter") == 1 and update_stutter)
      fx.apply_level(is_stuttering)

      -- reset occurrence booleans to default
      update_chance = false
      update_stutter = false
      update_variation = false
      update_glitch = false
    end

    -- glitch
    if update_glitch and not is_recording then
      for voice = 1, 2 do
        softcut.play(voice, 1)
        softcut.position(voice, (math.random() * loop_len))
        
        local randomize_rate = rand_occurrence(params:get("glitch"), true)
        local random_rate = (math.random() * params:get("glitch") / 10) * mathh.random(-params:get("glitch") / 100, params:get("glitch") / 100)
        if randomize_rate then
          glitch_rate[voice] = random_rate
        end
      end
    else
      glitch_rate = {1, 1}
    end
    fx.apply_rate(is_recording, glitch_rate)

    grid.increment_sum(beat_div)

    if (grid.sum >= BAR_VALS[interval.get()].value) then
      grid.reset_sum()
    end

    -- reset beat_div value
    grid.index = grid_index_prev
  end
end

--- Handler for repeat FX, applies LFO movement between clock ticks.
local function update_fx()
  while true do
    clock.sleep(1 / 30)
    fx.apply_rate(is_recording, glitch_rate)
    fx.apply_level(is_stuttering)
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

--- Init Softcut.
local function init_softcut()
  audio.level_adc(1) -- input volume 1
  audio.level_adc_cut(1) -- ADC to Softcut input
  audio.level_cut(1) -- Softcut master level (same as in LEVELS screen)
  audio.level_cut_rev(0) -- Softcut reverb send 0 (restored on cleanup)

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
    softcut.level_input_cut(voice, voice, 1) -- Softcut input level ch 1
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

  params:add_separator("repeat_separator", "Repeat")

  -- loop duration (Beat Repeat: interval)
  interval.add_params(BAR_VALS_STR, interval.index)

  -- clock division (Beat Repeat: grid)
  grid.add_params(BAR_VALS_STR, grid.index)

  -- prabability of repeat happening (e.g. softcut or passthrough) (Beat Repeat: chance)
  params:add_number("chance", "Chance", 0, 100, 100)
  params:set_action("chance", function(val)
      if (val <= 0) then
        update_stutter = false
      end
    end)

  -- offset starting position (by 1/16th notes) of record start (Beat Repeat: offset)
  params:add_number("offset", "Offset", 0, 15, 0)

  -- variation of clock division length (Beat Repeat: variation)
  params:add_number("variation", "Variation", 0, 10, 0)

  -- prabability of glitch
  params:add_number("glitch", "Glitch", 0, 100, 0)
  params:set_action("glitch", function(val)
      if (val <= 0) then
        update_glitch = false
      end
    end)

  -- glitchy params
  params:add_option("glitch_ui", "Glitch UI", {"yes", "no"}, 2)
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
  init_metro()
  fx.init_softcut()

  update_id = clock.run(update)
  fx_id = clock.run(update_fx)

  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
end

--- Encoder input.
-- @tparam index {number}  which encoder
-- @tparam delta {number}  amount of change/turn
function enc(index, delta)
  if index == 1 then
    ui.page_delta(delta)
    fx.shift = false
  end

  if (#norns.encoders.accel == 4) then
    -- Fates only; persistent BPM adjustment
    if index == 4 then
      params:delta("clock_tempo", delta)
    end
  else
    -- Norns; BPM only on page 0
    if ui.page_get() == 0 then
      if index == 2 then
        params:delta("clock_tempo", delta)
      end
    end
  end

  if ui.page_get() == 1 then
    if index == 2 then
      interval.delta(delta)
    elseif index == 3 then
      grid.delta(delta)
    end
  elseif ui.page_get() == 2 then
    if index == 2 then
      params:delta("offset", delta)
    elseif index == 3 then
      params:delta("chance", delta)
    end
  elseif ui.page_get() == 3 then
    if index == 2 then
      params:delta("variation", delta)
    elseif index == 3 then
      params:delta("glitch", delta)
    end
  elseif ui.page_get() == 4 then
    if index == 2 then
      params:delta("mode", delta)
    end
  elseif FX_PAGES[ui.page_get()] then
    local fx_page = FX_PAGES[ui.page_get()]
    if index == 2 then
      params:delta(fx.shift and (fx_page.target .. "_lfo_rate") or fx_page.main, delta)
    elseif index == 3 then
      params:delta(fx.shift and (fx_page.target .. "_lfo_depth") or fx_page.second, delta)
    end
  end
  
  redraw()
end

--- Key/button input.
-- @tparam index {number}  which button
-- @tparam state {boolean|number}  button pressed
function key(index, state)
  if index == 2 and state == 1 then
    grid.reset_sum()
  elseif index == 3 and state == 1 and FX_PAGES[params:get("page")] then
    -- hold K3 to edit LFO on FX pages
    fx.shift = true
  elseif index == 3 and state == 1 then
    if params:get("page") == 2 then
      chance_prev = params:get("chance")
      params:set("chance", 0)
    elseif params:get("page") == 3 then
      glitch_prev = params:get("glitch")
      params:set("glitch", 100)
    elseif params:get("page") == 4 and params:get("mode") == 2 then
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
    fx.shift = false
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
  return (params:get("glitch_ui") == 1) and update_glitch and not is_recording
end

--- Returns px value for shifting UI.
local function glitch_shift_px()
  if is_ui_glitching() then
    local glitch_val = math.random() * ((params:get("glitch") / 1000))

    return (1 + (mathh.random(-1, 1) * glitch_val))
  end

  return 1
end

--- Scales a screen coordinate by the current glitch shift (1 when not glitching).
-- @tparam v {number}  coordinate value
local function g(v)
  return v * glitch_shift_px()
end

--- Draws label with value and optional signal.
-- @tparam label {string}
-- @tparam value {string}
-- @tparam x {number}
-- @tparam y {number}
-- @tparam label_level {number}  brightness of label
-- @tparam value_level {number}  brightness of value and signal
-- @tparam bool {boolean}  Optional boolean to trigger signal
local function draw_cell(label, value, x, y, label_level, value_level, bool)
  screen.level(label_level)
  screen.move(g(x), g(y + 10))
  screen.text(string.sub(label, 1, 6))

  screen.level(value_level)
  if (bool ~= nil) then
    ui.signal(g(x + 3), g(y), bool)
    screen.move(g(x + 8), g(y + 2))
  else
    screen.move(g(x), g(y + 2))
  end
  screen.text(value)
end

--- Draws given param with signal and value.
-- @tparam name {string}  Name of parameter
-- @tparam page {number}
-- @tparam x {number}
-- @tparam y {number}
-- @tparam suffix {string}  Optional suffix for display value
-- @tparam bool {boolean}  Boolean to trigger signal
local function draw_param(name, page, x, y, suffix, bool)
  local is_active = ui.page_get() == page
  draw_cell(name, params:get(string.lower(name)) .. (suffix or ""), x, y,
    is_active and ui.ON or 0, is_active and ui.ON or ui.OFF, bool)
end

--- Displays string for BAR_VAL selected.
-- @tparam index {number}  index of length value 
-- @tparam str {number}  prefix
local function str_note_bar(index, str)
  if index < BAR_VALS_DETAIL_RES then return (str or "") .. " Note"
  elseif index == BAR_VALS_DETAIL_RES then return (str or "") .. " Bar"
  else return (str or "") .. " Bars" end
end

--- Draws tempo indicator and value (page 0).
local function draw_tempo()
  local page = 0
  if (#norns.encoders.accel == 4) then screen.level(ui.ON)
  else ui.highlight({page}) end
  ui.metro_icon(g(5), 5, update_tempo)
  screen.move(g(20), g(10))
  screen.text(util.round(clock.get_tempo()))
end

--- Draws interval and grid length markers (page 1).
-- @tparam bar_y {number}  Y-coordinate of the bar
-- @treturn number  Y-coordinate below the grid label, for following rows
local function draw_bars(bar_y)
  local page = 1
  local width = interval.ui.width
  local interval_val = BAR_VALS[interval.get()].value
  local grid_val = BAR_VALS[grid.index].value
  -- at 1 bar or less, the bar is drawn as a single detailed bar
  local is_detail = interval.get() <= BAR_VALS_DETAIL_RES
  local scale = is_detail and (width * 4) or width
  local div = is_detail and (interval_val / grid_val) or nil

  -- interval length marker(s)
  local interval_w = (is_detail and scale or (width * interval_val)) / 4

  screen.level(2)
  if not is_detail then
    interval.draw(g(2), g(bar_y), 4)
  end

  ui.highlight({page})
  interval.draw(g(2), g(bar_y), div, g(interval_w))
  screen.move(g(interval_w), g(bar_y - 3))
  screen.text_right(str_note_bar(interval.get(), BAR_VALS[interval.get()].str))

  -- grid length marker(s)
  local grid_w = div and (width / div) or (scale * grid_val / 4)
  local label_y = bar_y + grid.ui.height + 7

  if update_chance then
    screen.level(ui.ON)
  else
    ui.highlight({page})
  end
  grid.draw_span(g(2 + ((grid.pos - 1) * grid_w)), g(bar_y), grid_w)

  -- offset marker, in 1/16 note steps
  local offset_x = 2 + (scale * BAR_VALS[7].value * params:get("offset")) / 4

  ui.highlight({page})
  grid.draw_span(g(offset_x), g(bar_y), grid_w)
  screen.move(g(offset_x), g(label_y))
  screen.text(str_note_bar(grid.get(), BAR_VALS[grid.index].str))

  return label_y
end

--- Draws offset, chance, variation and glitch values (pages 2 & 3).
-- @tparam y {number}  Y-coordinate of the row
local function draw_params(y)
  draw_param("Offset", 2, 2, y, "/16")
  draw_param("Chance", 2, (ui.VIEWPORT.width * .33) - 8, y, "%", update_chance)
  draw_param("Variation", 3, (ui.VIEWPORT.width * .63) - 8, y, "", update_variation)
  draw_param("Glitch", 3, ui.VIEWPORT.width * .83, y, "%", update_glitch)
end

--- Returns display string for repeat FX param.
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

  return val .. "%"
end

--- Draws repeat FX values for current FX page (pages 5 - 7).
-- @tparam fx_page {table}  entry of FX_PAGES
-- @tparam y {number}  Y-coordinate of the row
local function draw_fx_params(fx_page, y)
  local main_level = fx.shift and ui.OFF or ui.ON
  local lfo_level = fx.shift and ui.ON or ui.OFF
  local depth_id = fx_page.target .. "_lfo_depth"
  local lfo_on = params:get(depth_id) > 0 and fx.lfo[fx_page.target].value > 0
  local filter_on = nil
  if fx_page.target == "filter" then
    filter_on = params:get("filter") == 2
  end

  draw_cell(fx_page.labels[1], fx_str(fx_page.main), 2, y, main_level, main_level, filter_on)
  draw_cell(fx_page.labels[2], fx_str(fx_page.second), (ui.VIEWPORT.width * .33) - 8, y, main_level, main_level)
  draw_cell("Rate", fx_str(fx_page.target .. "_lfo_rate"), (ui.VIEWPORT.width * .63) - 8, y, lfo_level, lfo_level, lfo_on)
  draw_cell("Depth", fx_str(depth_id), ui.VIEWPORT.width * .83, y, lfo_level, lfo_level)
end

--- Draws live/sample mode indicators (page 4).
local function draw_mode()
  local center = ui.VIEWPORT.center
  local is_live = params:get("mode") == 1

  -- live input recording
  if is_live then
    screen.level(is_recording and ui.ON or ui.OFF)
    screen.move(center - g(15), g(10))
    screen.text("REC")
  end
  screen.level(is_live and ui.ON or ui.OFF)
  ui.recording(center - g(20), g(10))

  -- tape/sample input playback
  screen.level(is_live and ui.OFF or ui.ON)
  ui.tape_icon(center + g(10), g(10))

  if params:get("sample") ~= "-" and params:get("sample") ~= nil then
    screen.rect(center + g(8), g(4), 16, 8)
    screen.stroke()
  end
end

--- Handler for screen redraw.
function redraw()
  -- skipping clear while glitching leaves trails on screen
  if not is_ui_glitching() then
    screen.clear()
  end

  screen.level(ui.ON)
  ui.page_marker(15, 10, ui.page_get(), glitch_shift_px)

  draw_tempo()
  local y = draw_bars(24)
  if FX_PAGES[ui.page_get()] then
    draw_fx_params(FX_PAGES[ui.page_get()], y + 8)
  else
    draw_params(y + 8)
  end
  draw_mode()

  screen.update()
end

--- Restores system mixer params this script changes directly via `audio`.
local function restore_mixer()
  for _, id in ipairs({"input_level", "softcut_level", "rev_cut_input", "cut_input_adc"}) do
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
