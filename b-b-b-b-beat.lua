--
-- B-B-B-B-Beat
-- 0.9.4
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
local VERSION = "0.9.4"

local BEAT_VALS = {
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
local BEAT_VALS_STR = {}
for i = 1, #BEAT_VALS do
  BEAT_VALS_STR[i] = BEAT_VALS[i].str
end

-- Generate Gate value constants
local GATE_VALS = {}
local GATE_VALS_STR = {}
for i = 1, 15 do
  GATE_VALS[i] = {
    str = i .. "/16",
    value = i / 16,
    ppq = 4
  }
  GATE_VALS_STR[i] = i .. "/16"
end
for i = 16, 19 do
  GATE_VALS[i] = {
    str = BEAT_VALS[i - 5].str,
    value = BEAT_VALS[i - 5].value,
    ppq = BEAT_VALS[i - 5].ppq
  }
  GATE_VALS_STR[i] = BEAT_VALS[i - 5].str
end


-- Index of BEAT_VALS that triggers detail view (default: 1 bar)
local BEAT_VALS_DETAIL_RES = 11 


local fileselect = require 'fileselect'
local mathh = include("lib/math_helper")
local passthrough = include("lib/passthrough")
local utils = include("lib/core/utils")
local ui = include("lib/core/ui")

local grid = include("lib/core/interval")
grid.name = "Grid"
grid.index = 10 -- init/default: 1/2 note

local interval = include("lib/core/interval")
interval.name = "Interval"
interval.index = 12 -- init/default: 2 bars

local gate = include("lib/core/interval")
gate.name = "Gate"
gate.index = 1

--- Defaults
local bpm = 60
local beat_div = BEAT_VALS[1].value
local loop_len = 0
local tape_len = 0
local update_id

--- States
local is_recording = true
local is_playing = true
local is_selecting_file = false
local update_tempo = true
local update_gate = true

local update_chance = false
local update_stutter = false
local update_variation = false
local update_glitch = false


--- Sets loop length based on grid length and tempo.
local function set_loop_len()
  if tape_len <= 0 then -- changing loop length of a loaded sample, stops the sample from playing
    loop_len = (BEAT_VALS[(grid.index or 1)].value / params:get("clock_tempo")) * 60

    for voice = 1, 2 do
      softcut.loop_end(voice, loop_len)
    end
  end 
end

--- Handler for Softcut play state.
local function softcut_play_handler()
  local offset_val = (params:get("offset") / 16)

  if (grid.sum > GATE_VALS[gate.get()].value) then
    is_playing = false

    if tape_len <= 0 then
      for voice = 1, 2 do
        softcut.play(voice, 0)
      end
    end
    -- audio.level_cut(0)
  elseif grid.sum - offset_val >= 0 then
    is_playing = true

    for voice = 1, 2 do
      softcut.play(voice, 1)
    end
    -- audio.level_cut(1.0)
  end
end

--- Handler for ADC output level, depending on output mode
local function output_level_adc()
  if (params:string("output_mode") == "mix") then
    audio.level_adc(1.0)
  elseif (params:string("output_mode") == "insert") then
    if update_chance then
      audio.level_adc(0)
      if not is_playing then
        audio.level_adc(1.0)
      end
    else
      audio.level_adc(1.0)
    end
  elseif (params:string("output_mode") == "gate") then
    audio.level_adc(0)
  end
end

--- Starts recording into Softcut.
local function start_rec()
  -- TODO(frederickk): Is there a way to record incoming audio, without having it pass through?
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

  for voice = 1, 2 do
    softcut.rec_level(voice, 0)
  end
end

--- Handler for clock update sync, fires at `beat_div` interval.
local function update()
  while true do
    clock.sync(beat_div * 4)

    -- randomize occurrence booleans
    update_chance = utils.rand_occurrence(params:get("chance"), true)
    update_stutter = utils.rand_occurrence(params:get("glitch"), true)
    if (params:get("variation") > 0) then
      update_variation = utils.rand_occurrence(params:get("variation") * 10, true)
    end
    update_glitch = utils.rand_occurrence(params:get("glitch"), true)

    grid_index_prev = grid.index

    -- bang on beat as set by grid length
    if ((grid.sum * (BEAT_VALS[1].ppq * 4)) % math.floor(BEAT_VALS[1].ppq / BEAT_VALS[grid.index].ppq)) == 0 then
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

      if (params:get("glitch_stutter") == 1 and update_stutter and not is_recording) then
        -- audio.level_cut(0)
        audio.level_adc(0)
      end
      
      -- chance
      -- if update_chance and not is_recording then
      if update_chance then
        for voice = 1, 2 do
          softcut_play_handler()
          softcut.position(voice, 1)
        end
      -- elseif not update_chance and is_recording then
        -- print("not update_chance and is_recording", not update_chance and is_recording, update_chance, is_recording, tape_len)
      else
        if params:string("output_mode") == "gate" then
          for voice = 1, 2 do
            softcut.play(voice, 0)
          end
        end
      end

      output_level_adc()

      -- reset occurrence booleans to default
      update_chance = false
      update_stutter = false
      update_variation = false
      update_glitch = false
    end

    -- record incoming audio
    local offset_val = (params:get("offset") / 16)
    if (grid.sum == offset_val or grid.sum >= BEAT_VALS[interval.get()].value) then
      start_rec()
    elseif (grid.sum - offset_val == BEAT_VALS[grid.index].value) then
      stop_rec()
    end

    -- glitch
    if update_glitch and not is_recording then
      for voice = 1, 2 do
        -- softcut.play(voice, 1)
        softcut_play_handler()
        softcut.position(voice, (math.random() * loop_len))
        
        local randomize_rate = utils.rand_occurrence(params:get("glitch"), true)
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

    if (grid.sum >= BEAT_VALS[interval.get()].value) then
      grid.reset_sum()
    end

    -- reset beat_div value
    grid.index = grid_index_prev
  end
end

--- Handler for metro thread, e.g. screen redrawing.
local function update_metro(count)
  if is_selecting_file == false then
    redraw()
  end
end

--- Handler when "grid" parameter is set.
-- @param val number:  incoming param value
function grid.update(val)
  grid.index = mathh.clamp(val, 1, interval.index)

  if (val > interval.index) then
    grid.set(grid.index)
    return
  end

  beat_div = BEAT_VALS[1].value
  set_loop_len()
end

--- Handler when "interval" parameter is set.
-- @param val number:  incoming param value
function interval.update(val)
  interval.index = mathh.clamp(val, 5, #BEAT_VALS) -- 6, #BEAT_VALS)

  if (interval.index < grid.index) then
    grid.set(interval.index)
  end
end

--- Handler when "gate" parameter is set.
-- @param val number:  incoming param value
function gate.update(val)
  if (GATE_VALS[val].value > BEAT_VALS[interval.index].value) then
    gate.set(val - 1)
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

    softcut.fade_time(voice, BEAT_VALS[6].value) -- 1/32 note fade
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

--- Event handler for Midi/Link start commands.
function clock.transport.start()
  grid.reset_sum() 
end

--- Event handler for Midi/Link stop commands.
function clock.transport.stop()
  grid.reset_sum() 
end

--- Midi event, fires when Midi data receieved.
-- @param data table:  Midi data in bytes
-- TODO(frederickk): Add ability to repeat Midi input with Midi output.
local function midi_device_event(data)
  -- local msg = midi.to_msg(data)
end

--- Init Midi.
local function init_midi()
  passthrough.init()
  -- passthrough.user_device_event = midi_device_event
end

--- Init Metro.
local function init_metro()
  counter = metro.init()
  counter.time = BEAT_VALS[1].value * 4 -- sync is set to fastest possible 1/128
  counter.count = -1
  counter.event = update_metro
  counter:start()
end

--- Handler for loading sample into softcut.
-- @param string:  path to sound file
local function load_file(file)
  is_selecting_file = false

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
        is_selecting_file = false
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
  interval.add_params(BEAT_VALS_STR, interval.index)

  -- clock division (Beat Repeat: grid)
  grid.add_params(BEAT_VALS_STR, grid.index)

  -- length of repeats (Beat Repeat: gate)
  gate.add_params(GATE_VALS_STR, gate.index)

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

  -- output mode of signal (Beat Repeat: output mode)
  params:add_option("output_mode", "Output", {"mix", "insert", "gate"}, 1)

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
  init_midi()
  init_softcut()
  init_params()
  init_metro()

  update_id = clock.run(update)

  screen.level(15)
  screen.aa(0)
  screen.line_width(1)

  print("B-B-B-B-Beat v" .. VERSION)
end

--- Encoder input.
-- @param index number:  which encoder
-- @param delta number:  amount of change/turn
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
      grid.delta(delta)
    elseif index == 3 then
      interval.delta(delta)
    end
  elseif ui.page_get() == 2 then
    if index == 2 then
      params:delta("offset", delta)
    end
  elseif ui.page_get() == 3 then
    if index == 2 then
      params:delta("chance", delta)
    elseif index == 3 then
      params:delta("gate", delta)
    end
  elseif ui.page_get() == 4 then
    if index == 2 then
      params:delta("variation", delta)
    elseif index == 3 then
      params:delta("glitch", delta)
    end
  elseif ui.page_get() == 5 then
    if index == 2 then
      params:delta("mode", delta)
    elseif index == 3 then
      params:delta("output_mode", delta)
    end
  end
  
  redraw()
end

--- Key/button input.
-- @param index number:  which button
-- @param state boolean|number:  button pressed
function key(index, state)
  if index == 2 and state == 1 then
    grid.reset_sum()
  elseif index == 3 and state == 1 then
    chance_prev = params:get("chance")
    glitch_prev = params:get("glitch")

    if params:get("page") == 3 then
      params:set("chance", 0)
    elseif params:get("page") == 4 then
      params:set("glitch", 100)
    elseif params:get("page") == 5 and params:get("mode") == 2 then
      is_selecting_file = true
      fileselect.enter(_path.tape, function(file)
        params:set("sample", file)
      end)
    end
  end
  
  if state == 0 then
    if glitch_prev ~= nil then params:set("glitch", glitch_prev) end
    if chance_prev ~= nil then params:set("chance", chance_prev) end
  end
end

--- Returns px value for shifting UI.
-- @return number: random number based on Glitch param value or 1
local function glitch_shift_px()
  if (params:get("glitch_ui") == 1) and update_glitch and not is_recording then
    local glitch_val = math.random() * ((params:get("glitch") / 1000))

    return (1 + (mathh.random(-1, 1) * glitch_val))
  end

  return 1
end

--- Displays string for BAR_VAL selected.
-- @param index number:  index of length value 
-- @param str number:  prefix
-- @return string:
function str_note_bar(index, str)
  if index < BEAT_VALS_DETAIL_RES then return (str or "") .. " Note"
  elseif index == BEAT_VALS_DETAIL_RES then return (str or "") .. " Bar"
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
  ui.page_marker(10, 7, ui.page_get(), {
    glitch_func = glitch_shift_px
  })

  -- BPM
  page = 0
  if (#norns.encoders.accel == 4) then screen.level(ui.ON)
  else ui.highlight({page}) end
  ui.metro_icon(glitch_shift_px(), 2, update_tempo)
  screen.move(15 * glitch_shift_px(), 7 * glitch_shift_px())
  screen.text(string.upper(string.sub(params:string("clock_source"), 1, 1)) .. params:get("clock_tempo"))

  local grid_seg_num = (interval.ui.width * BEAT_VALS[interval.get()].value / (interval.ui.width * BEAT_VALS[grid.index].value))

  local str = BEAT_VALS[interval.get()].str
  local w = interval.ui.width * GATE_VALS[gate.get()].value
  local w_offset = (interval.ui.width * BEAT_VALS[7].value) * params:get("offset")
  if (interval.get() <= 11) then
    w_offset = ((interval.ui.width * 4) * BEAT_VALS[7].value) * params:get("offset")
  end
  local x = 2
  local y_bar = 23
  local y = y_bar - 4
  local div = nil

  page = 1
  -- gate length bar
  screen.level(2)
  grid.draw_span((2 + w_offset / 4) * glitch_shift_px(), y_bar * glitch_shift_px(), w, nil, 2)
  if (w_offset / 4) + w > interval.ui.width then
    w = w - (w_offset / 4)
    grid.draw_span(2 * glitch_shift_px(), y_bar * glitch_shift_px(), w, nil, 2)
  end

  -- interval length bar
  w = interval.ui.width * 4
  interval.draw(x * glitch_shift_px(), y_bar * glitch_shift_px(), 4)

  if (interval.get() <= BEAT_VALS_DETAIL_RES) then
    div = BEAT_VALS[interval.get()].value / BEAT_VALS[grid.index].value
  end
  
  ui.highlight({page})
  interval.draw(x * glitch_shift_px(), y_bar * glitch_shift_px(), div, (w / 4) * glitch_shift_px())
  screen.move(interval.ui.width * glitch_shift_px(), y * glitch_shift_px())
  screen.text_right(str_note_bar(interval.get(), str))

  -- grid length bar(s)
  str = BEAT_VALS[grid.index].str
  w = interval.ui.width * BEAT_VALS[grid.index].value
  if (interval.get() <= BEAT_VALS_DETAIL_RES) then
    w = (interval.ui.width * 4) * BEAT_VALS[grid.index].value
  end
  local grid_w = w / 4 
  if div ~= nil then
    grid_w = interval.ui.width / div
  end

  x = 2 + ((grid.pos - 1) * grid_w)

  if update_chance then
    screen.level(15)
  else
    ui.highlight({page})
  end

  grid.draw_span(x * glitch_shift_px(), y_bar * glitch_shift_px(), grid_w)

  ui.highlight({page, 2})
  grid.draw_span((2 + w_offset / 4) * glitch_shift_px(), y_bar * glitch_shift_px(), grid_w)
  -- screen.move((2 + w_offset / 4) * glitch_shift_px(), y * glitch_shift_px())
  screen.move(2 * glitch_shift_px(), y * glitch_shift_px())
  screen.text(str_note_bar(grid.get(), str))

  -- additional params
  y = y_bar + grid.ui.height + 9
  page = 2

  -- TODO(frederickk): Fix offset to affect Interval, not Grid.
  ui.highlight({page})
  ui.draw_param("Offset", page, (2 + w_offset / 4) * glitch_shift_px(), y - 3, {
    suffix = "/16",
    glitch_func = glitch_shift_px,
    label = false
  })

  y = y + 8
  page = 3
  ui.draw_param("Chance", page, 2, y, {
    suffix = "%",
    bool = update_chance,
    glitch_func = glitch_shift_px
  })
  ui.draw_param("Gate", page, (ui.VIEWPORT.width * .33) - 8, y, {
    bool = update_gate,
    glitch_func = glitch_shift_px
  })

  page = 4
  ui.draw_param("Variation", page, (ui.VIEWPORT.width * .63) - 8, y, {
    bool = update_variation,
    glitch_func = glitch_shift_px
  })
  ui.draw_param("Glitch", page, ui.VIEWPORT.width * .83, y, {
    suffix = "%",
    bool = update_glitch,
    glitch_func = glitch_shift_px
  })

  -- Live input recording 
  page = 5
  if params:get("mode") == 1 then
    if is_recording then
      screen.level(ui.ON)
    else
      screen.level(ui.OFF)
    end
    screen.move(47 * glitch_shift_px(), 7 * glitch_shift_px())
    screen.text("REC")

    screen.level(ui.ON)
  else
    screen.level(ui.OFF)
  end
  ui.recording(40 * glitch_shift_px(), 7 * glitch_shift_px())

  -- Tape/sample input playback
  if params:get("mode") == 2 then
    screen.level(ui.ON)
  else
    screen.level(ui.OFF)
  end
  ui.tape_icon(69 * glitch_shift_px(), 7 * glitch_shift_px())

  if params:get("sample") ~= "-" and params:get("sample") ~= nil then
    screen.rect(67 * glitch_shift_px(), 1 * glitch_shift_px(), 16, 8)
    screen.stroke()
  end

  ui.highlight({page})
  ui.speaker_icon(90, 2)
  screen.move(97 * glitch_shift_px(), 7 * glitch_shift_px())
  -- FIXME(frederickk): This is a really gnarly way to get first and last char of string.
  screen.text(string.upper(string.sub(params:string("output_mode"), 1, 1) .. string.sub(params:string("output_mode"), #params:string("output_mode"), #params:string("output_mode"))))

  screen.update()
end

--- Writes params on script end.
function cleanup()
  params:write()
end
