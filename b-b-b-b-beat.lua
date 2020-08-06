--
-- B-B-B-B-Beat
-- 0.0.5
-- llllllll.co/t/35047
--
-- K2    Resync to beat 1
-- K3    Randomize params
--
-- E1    Cycle through params
-- E4    BPM [Fates only]
-- E2-E3 Adjust highlight params
--
-- S-S-S-S-Stutter and
-- G-G-G-Glitch till your
-- hearts content
--
-- See README for more details
--

engine.name = "Glitch"


local mathh = include("lib/math_helper")
local passthrough = include("lib/passthrough")


-- constants
local VERSION = "0.0.5"
local FIRST_PAGE = 0
local LAST_PAGE = 3
local OFF = 3
local ON = 15

local VIEWPORT = {
  width = 128,
  height = 64,
  center = 64,
  middle = 32,
  padding = {
    x = 10,
    y = 15
  }
}

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

-- defaults
local bpm = 60
local grid_index = 10 -- init/default: 1/2 note
local interval_index = 12 -- init/default: 2 bars

-- Clock update vars
local beat_div = BAR_VALS[grid_index].value
local div_sum = 0
local loop_len = 0
local update_id

--
local update_tempo = true
local update_chance = false
local update_stutter = false
local update_variation = false
local update_glitch = false
local metro_pos = false


-- Generates random integer value
-- param_pct: param value (should generate value 0 - 100)
-- mult: multiplier; default = 10
local function rand(param_pct, mult)
  return math.floor(math.random() * (param_pct / 100) * (mult or 10))
end


-- Flip a given boolean bit... randomaly
-- param_pct: param value (should generate value 0 - 100)
-- val: the value to flip given boolean value
local function rand_occurrence(param_pct, val)
  local r = math.random()
  local bool_val = not val

  if (r < param_pct / 100) then
    bool_val = val
  end

  return bool_val
end


-- Clock update sync, fires at beat_div interval
local function update()
  while true do
    -- randomize occurance booleans
    update_chance = rand_occurrence(params:get("chance"), true)
    if (params:get("variation") > 0) then
      update_variation = rand_occurrence(params:get("chance"), true)
    end
    update_glitch = rand_occurrence(params:get("glitch"), true)
    update_stutter = rand_occurrence(params:get("glitch"), true)

    -- Variation
    if update_variation then
      local vari = params:get("variation")
      local vari_rand = math.floor(mathh.random(-vari, vari + 1))
      params:delta("grid", vari_rand)
    end

    clock.sync(beat_div)

    update_tempo = not update_tempo

    -- disable record
    if (div_sum == 0) then --BAR_VALS[params:get("interval")].value) then
      -- print("disable record", update_chance)
      audio.level_adc(0) -- set input volume 0

      for voice = 1, 2 do
        softcut.rec(voice, 0) -- disable recording
        softcut.rec_level(voice, 0) -- voice recording level 0
      end
    end

    div_sum = div_sum + beat_div

    -- reenable record
    if (div_sum >= BAR_VALS[params:get("interval")].value) then
      -- print("reenable record", update_chance)
      softcut.buffer_clear()
      audio.level_adc(1.0) -- set input volume 1.0

      for voice = 1, 2 do
        softcut.position(voice, 0)
        softcut.rec(voice, 1.0) -- enable recording
        softcut.rec_level(voice, 1.0) -- voice recording level 1.0
      end

      div_sum = 0
    end


    -- Chance
    if update_chance then
      for voice = 1, 2 do
        softcut.level(voice, 1.0)
        -- softcut.play(voice, 1)
      end
      -- audio.level_adc(0)
    else
      for voice = 1, 2 do
        -- softcut.level(voice, 0)
        -- softcut.play(voice, 0)
      end
      audio.level_adc(1.0)
    end

    -- Glitch
    if update_glitch then
      for voice = 1, 2 do
        softcut.position(voice, (math.random() * loop_len))
        softcut.rate(voice, ((math.random() * 2) * mathh.random(-params:get("glitch") / 10, params:get("glitch") / 10)))
      end

      if (params:get("glitch_noise") == 1 and not update_stutter) then
        local lfo_vol = mathh.random(1, 8)
        local cutoff = mathh.random_int(4000, 10000)
        local amp = mathh.random(0.01, 0.2)

      	engine.lfoVol(lfo_vol)
	    	engine.cutoff(cutoff)
	    	engine.amp(amp)
        engine.play()
		  end
    else
      engine.stop()
    end

    if (params:get("glitch_stutter") == 1 and update_stutter) then
      -- audio.level_adc(0)
      audio.level_cut(0)
    else
      -- audio.level_adc(1.0)
      audio.level_cut(1.0)
    end

    redraw()

    -- reset occurance booleans to default
    update_chance = false
    update_stutter = false
    update_variation = false
    update_glitch = false
  end
end


-- Event fired when "grid" parameter is set
local function update_grid(val)
  grid_index = mathh.clamp(val, 1, interval_index)

  if (val > interval_index) then
    params:set("grid", grid_index)
    return
  end

  beat_div = BAR_VALS[grid_index].value
  loop_len = (BAR_VALS[grid_index].value / params:get("clock_tempo")) * 60 -- set loop length to 1 bar (or 1 second)

  for voice = 1, 2 do
    softcut.loop_end(voice, loop_len)
  end

  div_sum = 0
end


-- Event fired when "interval" parameter is set
local function update_interval(val)
  interval_index = val

  if (interval_index < grid_index) then
    params:set("grid", interval_index)
  end

  div_sum = 0
end


-- Init/add params
local function init_params()
  -- Parameter page
  params:add_number("page", "Page", FIRST_PAGE - 1, LAST_PAGE + 1, 1)
  params:hide("page")

  params:add_separator()

  -- loop duration (Beat Repeat: interval)
  params:add_option("interval", "Interval", BAR_VALS_STR, interval_index)
  params:set_action("interval", update_interval)

  -- clock division (Beat Repeat: grid)
  params:add_option("grid", "Grid", BAR_VALS_STR, grid_index)
  params:set_action("grid", update_grid)

  -- prabability of repeat happening (e.g. softcut or passthrough) (Beat Repeat: chance)
  params:add_number("chance", "Chance", 0, 100, 100)
  params:set_action("chance", function(val)
      if (val <= 0) then
        update_stutter = false
      end
    end)

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
  params:add_option("glitch_noise", "Glitch noise", {"yes", "no"}, 1)
  params:add_option("glitch_ui", "Glitch UI", {"yes", "no"}, 1)
  params:add_option("glitch_stutter", "Glitch stutter", {"yes", "no"}, 2)

  -- event wrapper (of sorts) for setting global BPM
  params:add_number("bpm", "bpm", 1, 300, bpm) -- norns.state.clock.tempo)
  params:set_action("bpm",
    function(val)
      bpm = val
      params:set("clock_tempo", val)
      params:set("grid", grid_index)
      params:set("interval", interval_index)
    end)
  params:hide("bpm")

  params:add_separator()

  -- trigger param defaults
  params:bang()

  -- Load saved params
  params:read()
end


-- Randomize parameter values
function randomize_params()
  params:set("interval", mathh.random_int(1, #BAR_VALS))
  params:set("grid", mathh.random_int(1, #BAR_VALS))
  params:set("chance", mathh.random_int(0, 100))
  params:set("variation", mathh.random_int(0, 10))
  -- params:set("glitch", mathh.random_int(0, 100))
  -- params:set("glitch_noise", mathh.random_int(1, 2))
  -- params:set("glitch_ui", mathh.random_int(1, 2))
  -- params:set("glitch_stutter", mathh.random_int(1, 2))
end


-- Init Softcut
local function init_softcut()
  audio.level_adc(1.0) -- input volume 1.0
  -- audio.level_adc(0) -- input volume 0
	audio.level_adc_cut(1) -- ADC to Softcut input
	audio.level_cut(1.0) -- Softcut master level (same as in LEVELS screen)
  audio.level_cut_rev(0) -- Softcut reverb level 0
  audio.level_eng_rev(0) -- Engine reverb level 0

  softcut.buffer_clear() -- clear Softcut buffer

  for voice = 1, 2 do
    softcut.enable(voice, 1) -- enable voice 1
    softcut.buffer(voice, voice)
    softcut.level(voice, 1.0) -- Softcut voice 1 output level
    softcut.pan(voice, voice == 1 and -1.0 or 1.0)
    softcut.rate(voice, 1)

    softcut.loop(voice, 1) -- voice 1 enable loop
    softcut.loop_start(voice, 0) -- voice 1 loop start @ 0.0s
    loop_len = (BAR_VALS[1].value / params:get("clock_tempo")) * 60 -- set loop length to 1 bar (or 1 second)
    softcut.loop_end(voice, loop_len)
    -- softcut.fade_time(voice, 1)

    softcut.position(voice, 0) -- voice 1 loop position @ 0.0s
    softcut.level_input_cut(voice, voice, 1.0) -- Softcut input level ch 1
    softcut.pre_level(voice, 1.0) -- voice 1 overdub level
    softcut.rec_level(voice, 1.0) -- voice 1 record level
    softcut.rec(voice, 1) -- voice 1 enable record
  end

  for voice = 1, 2 do
    softcut.play(voice, 1) -- voice 1 enable playback
  end
end


-- Midi event, fires when Midi data receieved
function midi_device_event(data)
  local msg = midi.to_msg(data)

  if msg.type == "clock" then
  end

  redraw()
end


-- Initialize Midi
function init_midi()
  passthrough.init()
  passthrough.user_device_event = midi_device_event
end


-- I-I-I-I-Init
function init()
  print("b-b-b-b-beat v" .. VERSION)

  if (#norns.encoders.accel == 4) then
    FIRST_PAGE = 1
  end

  init_midi()
  init_params()
  init_softcut()

  update_id = clock.run(update)

  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
end


-- Encoder input
function enc(index, delta)
  if index == 1 then
    params:delta("page", delta)

    if (params:get("page") > LAST_PAGE) then
      params:set("page", FIRST_PAGE)
    elseif (params:get("page") < FIRST_PAGE) then
      params:set("page", LAST_PAGE)
    end
  end

  if (#norns.encoders.accel == 4) then
    -- Fates only; persistent BPM adjustment
    if index == 4 then
      params:delta("bpm", delta)
    end
  else
    -- Norns; BPM only on page 0
    if params:get("page") == 0 then
      if index == 2 then
        params:delta("bpm", delta)
      end
    end
  end

  if params:get("page") == 1 then
    if index == 2 then
      params:delta("interval", delta)
    elseif index == 3 then
      params:delta("grid", delta)
    end
  elseif params:get("page") == 2 then
    if index == 2 then
      params:delta("chance", delta)
    elseif index == 3 then
      params:delta("variation", delta)
    end
  elseif params:get("page") == 3 then
    if index == 2 then
      params:delta("glitch", delta)
    end
  end

  redraw()
end

-- Key/button input
function key(index, state)
  if index == 2 and state == 1 then
    div_sum = 1000
  elseif index == 3 and state == 1 then
    randomize_params()
  end

  redraw()
end


-- Toggles the brightness of an element based on page
-- on: brightnless level for "on" state
-- off: brightnless level for "off" state
-- page_nums: array of page numbers to toggle "on" state
local function highlight(on, off, page_nums)
  for i = 1, #page_nums do
    if params:get("page") == page_nums[i] then
      screen.level(on)
      break
    else
      screen.level(off)
    end
  end
end


-- Returns px value for shifting UI
local function glitch_shift_px()
  if (params:get("glitch_ui") == 1) and update_glitch then
    local glitch_val = math.random() -- * (params:get("glitch") / 100)

    return (1 + (mathh.random(-1, 0) * (glitch_val / 4)))
  end

  return 1
end


-- Creates activity element to signify status of parameter
-- x: X-coordinate of element
-- y: Y-coordinate of element
-- state: 1 is active, 0 is inactive
local function signal(x, y, state)
  local r = 3
  screen.move(math.floor(x) + r, math.floor(y))
  screen.circle(math.floor(x), math.floor(y), r)

  if (state) then screen.fill()
  else screen.stroke() end
end


-- Creates icon to show beat relative to interval
-- Thenk you @itsyourbedtime for creating this for Takt!
-- x: X-coordinate of element
-- y: Y-coordinate of element
local function metro_icon(x, y)
  screen.move(x + 2, y + 5)
  screen.line(x + 7, y)
  screen.line(x + 12, y + 5)
  screen.line(x + 3, y + 5)
  screen.stroke()
  screen.move(x + 7, y + 3)
  screen.line(metro_pos and (x + 4) or (x + 10), y )
  screen.stroke()

  if (div_sum == 0) then metro_pos = not metro_pos end
end


-- Screen handler
function redraw()
  screen.clear()
  screen.level(ON)

  local bar_y = 25 * glitch_shift_px()
  local bar_w = VIEWPORT.width - 10
  local bar_h = 10

  -- Page marker
  screen.move((VIEWPORT.width - 13) * glitch_shift_px(), 12)
  screen.text_center("P" .. params:get("page"))
  screen.line_width(1)
  screen.rect(VIEWPORT.width - 10 - 9, 12 - 6, 15, 8)
  screen.stroke()

  -- BPM
  page = 0
  if (#norns.encoders.accel == 4) then
    screen.level(ON)
  else
    highlight(ON, OFF, {page})
  end
  metro_icon(10 * glitch_shift_px(), 8 * glitch_shift_px())
  signal(5, 10 * glitch_shift_px(), update_tempo)
  screen.move(25 * glitch_shift_px(), 12 * glitch_shift_px())
  screen.text(params:get("clock_tempo"))

  page = 1

  -- interval
  local w = bar_w * BAR_VALS[params:get("interval")].value
  local str = BAR_VALS[params:get("interval")].str
  screen.level(OFF)
  screen.rect(5, bar_y, bar_w, bar_h + 1)
  screen.level(OFF - 2)
  for i = 1, 3 do
    screen.move(5 + (bar_w / 4) * i, bar_y * glitch_shift_px())
    screen.line(5 + (bar_w / 4) * i, (bar_y + bar_h) * glitch_shift_px())
  end
  screen.stroke()

  highlight(ON, 0, {page})
  screen.move((w / 4) + (#str * 6), bar_y - 3)
  screen.text("Interval")
  highlight(ON, OFF, {page})
  screen.rect(5 * glitch_shift_px() , bar_y, w / 4, bar_h + 1)
  screen.stroke()
  screen.move(w / 4, bar_y - 3)
  screen.text(str)

  -- grid
  highlight(ON, 0, {page})
  w = bar_w * BAR_VALS[params:get("grid")].value
  str = BAR_VALS[params:get("grid")].str
  screen.move((w / 4) + (#str * 6), bar_y + bar_h + 9)
  screen.text("Grid")
  highlight(ON, OFF, {page})
  screen.rect(5, bar_y, w / 4, bar_h)
  screen.fill()
  screen.move(w / 4, bar_y + bar_h + 9)
  screen.text(str)


  page = 2
  highlight(ON, OFF, {page})

  -- chance
  signal(5, bar_y + bar_h + 17, update_chance)
  screen.move(10 * glitch_shift_px() , bar_y + bar_h + 20)
  screen.text(params:get("chance") .. "%")
  screen.move(10 * glitch_shift_px() , bar_y + bar_h + 28)
  highlight(ON, 0, {page})
  screen.text("Chance")

  -- variation
  highlight(ON, OFF, {page})
  signal((VIEWPORT.width / 2) - 5 , bar_y + bar_h + 17, update_variation)
  screen.move((VIEWPORT.width / 2)  * glitch_shift_px() , bar_y + bar_h + 20)
  screen.text(params:get("variation"))
  screen.move((VIEWPORT.width / 2) * glitch_shift_px() , bar_y + bar_h + 28)
  highlight(ON, 0, {page})
  screen.text("Variation")

  page = 3
  highlight(ON, OFF, {page})

  -- glitch
  signal(VIEWPORT.width * .75, bar_y + bar_h + 17, update_glitch or update_stutter)
  screen.move(((VIEWPORT.width * .75) +  5) * glitch_shift_px(), bar_y + bar_h + 20)
  screen.text(params:get("glitch") .. "%")
  screen.move(((VIEWPORT.width * .75) + 5) * glitch_shift_px(), bar_y + bar_h + 28)
  highlight(ON, 0, {page})
  screen.text("Glitch")

  if update_glitch then
    screen.font_size(8 + math.floor(math.random() * (params:get("glitch") / 100)))
  else
    screen.font_size(8)
  end

  screen.update()
end


function cleanup()
  params:write()
end