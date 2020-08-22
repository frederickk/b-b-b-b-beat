--
-- B-B-B-B-Beat
-- 0.9.2
-- llllllll.co/t/35047
--
-- K2    Resync to beat 1
-- K3    See README
--
-- E1    Cycle through params
-- E4    BPM [Fates only]
-- E2-E3 Adjust highlight params
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
local VERSION = "0.9.2"

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


local fileselect = require 'fileselect'
local mathh = include("lib/math_helper")
local passthrough = include("lib/passthrough")
local ui = include("lib/core/ui")

local grid = include("lib/core/grid")
grid.name = "Grid"
grid.index = 10 -- init/default: 1/2 note

local interval = include("lib/core/grid")
interval.name = "Interval"
interval.index = 12 -- init/default: 2 bars

--- Defaults
local bpm = 60
local beat_div = BAR_VALS[1].value --grid.index].value
local loop_len = 0
local tape_len = 0
local update_id

--- States
local is_recording = true
local selecting_file = false
local update_tempo = true
local update_chance = false
local update_stutter = false
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
    loop_len = (BAR_VALS[(grid.index or 1)].value / params:get("clock_tempo")) * 60
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

      if (params:get("glitch_stutter") == 1 and update_stutter) then
        audio.level_cut(0)
      else
        audio.level_cut(1)
      end

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
        random_rate = (math.random() * params:get("glitch") / 10) * mathh.random(-params:get("glitch") / 100, params:get("glitch") / 100)
        if randomize_rate then
          softcut.rate(voice, random_rate)
        end
      end
    else
      for voice = 1, 2 do
        softcut.rate(voice, 1)
      end
    end

    grid.increment_sum(beat_div)

    if (grid.sum >= BAR_VALS[interval.get()].value) then
      grid.reset_sum()
    end

    -- reset beat_div value
    grid.index = grid_index_prev
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
  audio.level_cut_rev(0) -- Softcut reverb level 0
  audio.rev_off() -- disable reverb

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
function init_midi()
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

--- Init Metro.
function init_metro()
  counter = metro.init()
  counter.time = BAR_VALS[1].value * 4 -- sync is set to fastest possible 1/128
  counter.count = -1
  counter.event = update_metro
  counter:start()
end

--- Handler for loading sample into softcut.
-- @tparam {string}  path to sound file
local function load_file(file)
  selecting_file = false

  if file ~= "cancel" and params:get("mode") == 2 then
    is_recording = false
    local ch, samples = audio.file_info(file)
    tape_len = samples / 48000

    grid.reset_sum()
    softcut.buffer_clear()
    softcut.buffer_read_stereo(file, 0, 1, -1)
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

  params:add_separator()

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
  params:add_option("glitch_ui", "Glitch UI", {"yes", "no"}, 1)
  params:add_option("glitch_stutter", "Glitch stutter", {"yes", "no"}, 2)

  -- wrapper for listening to and setting global BPM
  params:add_number("bpm", "bpm", 1, 300, bpm)
  params:set_action("bpm",
    function(val)
      bpm = val
      params:set("clock_tempo", val)
      grid.set(grid.index)
      interval.set(interval.index)
    end)
  params:hide("bpm")

  params:add_separator()

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

  update_id = clock.run(update)

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
  end

  if (#norns.encoders.accel == 4) then
    -- Fates only; persistent BPM adjustment
    if index == 4 then
      params:delta("bpm", delta)
    end
  else
    -- Norns; BPM only on page 0
    if ui.page_get() == 0 then
      if index == 2 then
        params:delta("bpm", delta)
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
    chance_prev = params:get("chance")
    glitch_prev = params:get("glitch")

    if params:get("page") == 2 then
      params:set("chance", 0)
    elseif params:get("page") == 3 then
      params:set("glitch", 100)
    elseif params:get("page") == 4 and params:get("mode") == 2 then
      selecting_file = true
      fileselect.enter(_path.tape, load_file)
    end
  end
  
  if state == 0 then
    params:set("glitch", glitch_prev)
    params:set("chance", chance_prev)
  end
end

--- Returns px value for shifting UI.
local function glitch_shift_px()
  if (params:get("glitch_ui") == 1) and update_glitch and not is_recording then
    local glitch_val = math.random() * ((params:get("glitch") / 1000))

    return (1 + (mathh.random(-1, 1) * glitch_val))
  end

  return 1
end

--- Draws given param with signal and value.
-- @tparam name {string}  Name of parameter
-- @tparam page {number}
-- @tparam x {number}
-- @tparam y {number}
-- @tparam suffix {string}  Optional suffix for display value
-- @tparam bool {boolean}  Boolean to trigger signal
local function draw_param(name, page, x, y, suffix, bool)
  ui.highlight({page}, ui.ON, 0)
  screen.move(x * glitch_shift_px() , (y + 10) * glitch_shift_px())
  screen.text(string.sub(name, 1, 6))

  ui.highlight({page})
  if (bool ~= nil) then
    ui.signal((x + 3) * glitch_shift_px(), y * glitch_shift_px(), bool)
    screen.move((x + 8) * glitch_shift_px(), (y + 2) * glitch_shift_px())
  else
    screen.move(x * glitch_shift_px(), (y + 2) * glitch_shift_px())
  end
  screen.text(params:get(string.lower(name)) .. (suffix or ""))
end

--- Displays string for BAR_VAL selected.
-- @tparam index {number}  index of length value 
-- @tparam str {number}  prefix
function str_note_bar(index, str)
  if index < BAR_VALS_DETAIL_RES then return (str or "") .. " Note"
  elseif index == BAR_VALS_DETAIL_RES then return (str or "") .. " Bar"
  else return (str or "") .. " Bars" end
end

--- Handler for screen redraw.
-- TODO(frederickk): Refactor for clarity and simplicity.
function redraw()
  if not update_glitch then	
    screen.clear()
  end

  screen.level(ui.ON)

  -- page marker
  ui.page_marker(15, 10, ui.page_get(), glitch_shift_px)

  -- BPM
  page = 0
  if (#norns.encoders.accel == 4) then screen.level(ui.ON)
  else ui.highlight({page}) end
  ui.metro_icon(5 * glitch_shift_px(), 5, update_tempo)
  screen.move(20 * glitch_shift_px(), 10 * glitch_shift_px())
  screen.text(params:get("clock_tempo"))

  local bar_y = 24
  local grid_seg_num = (interval.ui.width * BAR_VALS[interval.get()].value / (interval.ui.width * BAR_VALS[grid.index].value))

  page = 1
  -- interval length marker(s)
  local str = BAR_VALS[interval.get()].str
  local w = interval.ui.width * BAR_VALS[interval.get()].value
  if (interval.get() <= BAR_VALS_DETAIL_RES) then
    w = interval.ui.width * 4
  end
  local x = 2
  local y = bar_y - 3

  screen.level(2)
  if (interval.get() > BAR_VALS_DETAIL_RES) then
    interval.draw(x * glitch_shift_px(), bar_y * glitch_shift_px(), 4)
  end

  local div = nil
  if (interval.get() <= BAR_VALS_DETAIL_RES) then
    div = BAR_VALS[interval.get()].value / BAR_VALS[grid.index].value
  end
  
  ui.highlight({page})
  interval.draw(x * glitch_shift_px(), bar_y * glitch_shift_px(), div, (w / 4) * glitch_shift_px())
  screen.move((w / 4) * glitch_shift_px(), y * glitch_shift_px())
  screen.text_right(str_note_bar(interval.get(), str))

  -- grid length marker(s)
  str = BAR_VALS[grid.index].str
  w = interval.ui.width * BAR_VALS[grid.index].value
  if (interval.get() <= BAR_VALS_DETAIL_RES) then
    w = (interval.ui.width * 4) * BAR_VALS[grid.index].value
  end
  local grid_w = w / 4 
  if div ~= nil then
    grid_w = interval.ui.width / div
  end

  x = 2 + ((grid.pos - 1) * grid_w)
  y = bar_y + grid.ui.height + 7

  if update_chance then
    screen.level(15)
  else
    ui.highlight({page})
  end

  grid.draw_span(x * glitch_shift_px(), bar_y * glitch_shift_px(), grid_w)

  ui.highlight({page})
  local offset_w = (interval.ui.width * BAR_VALS[7].value) * params:get("offset")
  if (interval.get() <= 11) then
    offset_w = ((interval.ui.width * 4) * BAR_VALS[7].value) * params:get("offset")
  end
  grid.draw_span((2 + offset_w / 4) * glitch_shift_px(), bar_y * glitch_shift_px(), grid_w)
  screen.move((2 + offset_w / 4) * glitch_shift_px(), y * glitch_shift_px())
  screen.text(str_note_bar(grid.get(), str))

  -- additional params
  page = 2
  draw_param("Offset", page, 2, y + 8, "/16")
  draw_param("Chance", page, (ui.VIEWPORT.width * .33) - 8, y + 8, "%", update_chance)

  page = 3
  draw_param("Variation", page, (ui.VIEWPORT.width * .63) - 8, y + 8, "", update_variation)
  draw_param("Glitch", page, ui.VIEWPORT.width * .83, y + 8, "%", update_glitch)

  -- Live input recording 
  page = 4
  if params:get("mode") == 1 then
    if is_recording then
      screen.level(ui.ON)
    else
      screen.level(ui.OFF)
    end
    screen.move(ui.VIEWPORT.center - 15, 10)
    screen.text("REC")

    screen.level(ui.ON)
  else
    screen.level(ui.OFF)
  end
  ui.recording(ui.VIEWPORT.center - 20, 10)

  -- Tape/sample input playback
  if params:get("mode") == 2 then
    screen.level(ui.ON)
  else
    screen.level(ui.OFF)
  end
  ui.tape_icon(ui.VIEWPORT.center + 10, 10)

  if params:get("sample") ~= "-" and params:get("sample") ~= nil then
    screen.rect(ui.VIEWPORT.center + 8, 4, 16, 8)
    screen.stroke()
  end

  screen.update()
end

--- Writes params on script end.
function cleanup()
  params:write()
end
