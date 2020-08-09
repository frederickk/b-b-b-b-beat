--
-- B-B-B-B-Beat
-- 0.7.3
-- llllllll.co/t/35047
--
-- K2    Resync to beat 1
-- K3    Toggle glitch 
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
--

--- constants
local VERSION = "0.7.3"

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


local mathh = include("lib/math_helper")
local passthrough = include("lib/passthrough")
local ui = include("core/ui")

local grid = include("core/grid")
grid.name = "Grid"
grid.index = 10 -- init/default: 1/2 note

local interval = include("core/grid")
interval.name = "Interval"
interval.index = 12 -- init/default: 2 bars

-- defaults
local bpm = 60
local beat_div = BAR_VALS[1].value --grid.index].value
local loop_len = 0
local update_id

-- states
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
  -- set loop length to 1 bar (or 1 second)
  loop_len = (BAR_VALS[(grid.index or 1)].value / params:get("clock_tempo")) * 60
  for voice = 1, 2 do
    softcut.loop_end(voice, loop_len * 4)
  end
end

--- Starts recording into Softcut.
local function start_rec()
  -- print("reenable record")
  softcut.buffer_clear()
  audio.level_adc(1.0)

  for voice = 1, 2 do
    softcut.position(voice, 0)
    softcut.rec(voice, 1.0)
    softcut.rec_level(voice, 1.0)
  end
end

--- Stops recording into softcut.
local function stop_rec()
  -- print("disable record", update_chance)
  audio.level_adc(0)

  for voice = 1, 2 do
    softcut.rec(voice, 0) 
    softcut.rec_level(voice, 0)
  end
end

--- Handler for clock update sync, fires at `beat_div` interval.
local function update()
  while true do
    -- clock.sync(beat_div * 4)
    clock.sync(BAR_VALS[1].value * 4) -- sync is set to fastest possible 1/128

    -- randomize occurrence booleans
    update_chance = rand_occurrence(params:get("chance"), true)
    update_stutter = rand_occurrence(params:get("glitch"), true)
    if (params:get("variation") > 0) then
      update_variation = rand_occurrence(params:get("chance"), true)
    end
    update_glitch = rand_occurrence(params:get("glitch"), true)

    -- variation
    if update_variation then
      local vari = params:get("variation")
      local vari_rand = mathh.random_int(-vari - 1, vari)
      beat_div_vari = beat_div * vari_rand
    else
      beat_div_vari = 0
    end

    -- recording incoming audio
    local offset_val = (params:get("offset") / 16)
    if (grid.sum == offset_val or grid.sum >= BAR_VALS[interval.get()].value) then
      print("---------")
      print("RECORD •")
      start_rec()
    elseif (grid.sum - offset_val == BAR_VALS[grid.index].value) then
      print("RECORD X")
      stop_rec()
    end

    -- bang on beat as set by grid length
    if ((grid.sum * (BAR_VALS[1].ppq * 4)) % math.floor(BAR_VALS[1].ppq / BAR_VALS[grid.index].ppq)) == 0 then
      redraw()

      update_tempo = not update_tempo
      grid.increment_pos(1)

      -- chance
      -- TODO(frederickk): Solve passthrough when repeat isn't triggered.
      if update_chance then
        -- print("---------")
        -- print("update_chance", update_chance)
        for voice = 1, 2 do
          softcut.play(voice, 1)
        end
        audio.level_adc(0)
      else
        -- for voice = 1, 2 do
        --   softcut.play(voice, 0)
        -- end
        -- audio.level_adc(1.0)
      end

      if (params:get("glitch_stutter") == 1 and update_stutter) then
        -- audio.level_adc(0)
        audio.level_cut(0)
      else
        -- audio.level_adc(1.0)
        audio.level_cut(1.0)
      end

      -- reset occurrence booleans to default
      update_chance = false
      update_stutter = false
      update_variation = false
      update_glitch = false
    end

    -- glitch
    if update_glitch then
      for voice = 1, 2 do
        softcut.position(voice, (math.random() * loop_len))
        softcut.rate(voice, ((math.random() * 2) * mathh.random(-params:get("glitch") / 10, params:get("glitch") / 10)))
      end
    else
      for voice = 1, 2 do
        softcut.rate(voice, 1.0)
      end
    end

    grid.increment_sum((beat_div + beat_div_vari))

    if (grid.sum >= BAR_VALS[interval.get()].value) then
      grid.reset_sum()
    end

  end
end

-- Handler when "grid" parameter is set.
function grid.update(val)
  grid.index = mathh.clamp(val, 1, interval.index)

  if (val > interval.index) then
    grid.set(grid.index)
    return
  end

  -- ssu BAR_VALS[grid.index].value
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

--- Init/add params.
local function init_params()
  ui.add_page_params()

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
  -- params:set_action("offset", function(val)
  --     local len = ((val / 16) / params:get("clock_tempo")) * 60
  --     for voice = 1, 2 do
  --       softcut.rec_offset(voice, len * 4)
  --     end
  --   end)

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

--- Init Softcut.
local function init_softcut()
  audio.level_adc(1.0) -- input volume 1.0
  -- audio.level_adc(0) -- input volume 0
  audio.level_adc_cut(1) -- ADC to Softcut input
  audio.level_cut(1.0) -- Softcut master level (same as in LEVELS screen)
  audio.level_cut_rev(0) -- Softcut reverb level 0

  softcut.buffer_clear() -- clear Softcut buffer

  for voice = 1, 2 do
    softcut.enable(voice, 1) -- enable voice 1
    softcut.buffer(voice, voice)
    softcut.level(voice, 1.0) -- Softcut voice 1 output level
    softcut.pan(voice, voice == 1 and -1.0 or 1.0)
    softcut.rate(voice, 1)

    softcut.loop(voice, 1) -- voice 1 enable loop
    softcut.loop_start(voice, 0) -- voice 1 loop start @ 0.0s
    set_loop_len()
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

--- Init Midi.
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

--- I-I-I-I-Init.
function init()
  print("b-b-b-b-beat v" .. VERSION)

  init_midi()
  init_params()
  init_softcut()

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
  end

  redraw()
end

--- Key/button input.
-- @tparam index {number}  which button
-- @tparam state {boolean|number}  button pressed
function key(index, state)
  glitch_ = params:get("glitch")

  if index == 2 and state == 1 then
    grid.reset_sum()
  elseif index == 3 and state == 1 then
    if (glitch_ == 100) then
      params:set("glitch", 0)
    else
      params:set("glitch", 100)
    end
  end
  
  if state == 0 then
    params:set("glitch", glitch_)
  end

  redraw()
end

--- Returns px value for shifting UI.
local function glitch_shift_px()
  if (params:get("glitch_ui") == 1) and update_glitch then
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
  ui.page_marker(32, 10, ui.page_get(), glitch_shift_px)

  -- BPM
  page = 0
  if (#norns.encoders.accel == 4) then screen.level(ui.ON)
  else ui.highlight({page}) end
  ui.signal(5 * glitch_shift_px(), 7 * glitch_shift_px(), grid.sum == (params:get("offset") / 16))
  ui.metro_icon(10 * glitch_shift_px(), 5, update_tempo)
  screen.move(25 * glitch_shift_px(), 10 * glitch_shift_px())
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
  if (interval.get() >= BAR_VALS_DETAIL_RES) then
    interval.draw(x * glitch_shift_px(), bar_y * glitch_shift_px(), 4)
  end

  local div = nil
  if (interval.get() <= BAR_VALS_DETAIL_RES) then
    div = BAR_VALS[grid.index].ppq * 4
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

  x = 2 + ((grid.pos) * (w / 4))
  y = bar_y + grid.ui.height + 7

  if update_chance then
    screen.level(15)
  else
    ui.highlight({page})
  end
  grid.draw_span(x * glitch_shift_px(), bar_y * glitch_shift_px(), w / 4)

  ui.highlight({page})
  local offset_w = (interval.ui.width * BAR_VALS[7].value) * params:get("offset")
  if (interval.get() <= 11) then
    offset_w = ((interval.ui.width * 4) * BAR_VALS[7].value) * params:get("offset")
  end
  grid.draw_span((2 + offset_w / 4) * glitch_shift_px(), bar_y * glitch_shift_px(), w / 4)
  screen.move((2 + offset_w / 4) * glitch_shift_px(), y * glitch_shift_px())
  screen.text(str_note_bar(grid.get(), str))

  -- additional params
  page = 2
  draw_param("Offset", page, 2, y + 8, "/16")
  draw_param("Chance", page, (ui.VIEWPORT.width * .33) - 8, y + 8, "%", update_chance)

  page = 3
  draw_param("Variation", page, (ui.VIEWPORT.width * .63) - 8, y + 8, "", update_variation)
  draw_param("Glitch", page, ui.VIEWPORT.width * .83, y + 8, "%", update_glitch)

  screen.update()
end

--- Writes params on script end.
function cleanup()
  params:write()
end
