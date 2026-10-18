local UI = {
  --- Viewport size and position constants.
  VIEWPORT = {
    width = 128,
    height = 64,
    center = 64,
    middle = 32
  },
  --- Default brightness state for "off" elements.
  OFF = 4,
  --- Default brightness state for "on" elements.
  ON = 15,
  -- Default first page index.
  FIRST_PAGE = 0,
  -- Default last page index; e.g. total pages
  LAST_PAGE = 12,
  -- Current active page
  active_page = 0,
  --- X-coordinates of the 4 cells in a param row.
  COLUMNS = {2, (128 * .33) - 8, (128 * .63) - 8, 128 * .83},
  --- Returns multiplier for "glitching" positions; script replaces it.
  glitch_func = function() return 1 end
}

--- Scales a screen coordinate by the current glitch shift (1 when not glitching).
-- @tparam v {number}  coordinate value
function UI.g(v)
  return v * UI.glitch_func()
end

--- Add params for Page
-- @tparam default_val {number}
function UI.add_page_params(default_val)
  params:add_number("page", "Page", UI.FIRST_PAGE - 1, UI.LAST_PAGE + 1, (default_val or 1))
  params:hide("page")
  params:add_separator()
end

--- Sets Page parameter value as delta
-- @tparam val {number}
function UI.page_delta(val)
  params:delta("page", val)

  if (params:get("page") > UI.LAST_PAGE) then
    params:set("page", UI.FIRST_PAGE)
  elseif (params:get("page") < UI.FIRST_PAGE) then
    params:set("page", UI.LAST_PAGE)
  end
end

--- Returns current page number.
function UI.page_get()
  return params:get("page")
end

--- Toggles the brightness of an element based on page.
-- @tparam page_nums {array}  page numbers to toggle "on" state
-- @tparam on  {number}  brightnless level for "on" state
-- @tparam off {number}  brightnless level for "off" state
function UI.highlight(page_nums, on, off)
  for i = 1, #page_nums do
    if params:get("page") == page_nums[i] then
      screen.level((on or UI.ON))
      break
    else
      screen.level((off or UI.OFF))
    end
  end
end

--- Creates marker for displaying current UI page.
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
-- @tparam page_num {number|string}  Page number to display
function UI.page_marker(x, y, page_num)
  screen.move(UI.g(UI.VIEWPORT.width - x), UI.g(y))
  screen.text_center("P" .. page_num)
  screen.line_width(1)
  screen.rect(UI.VIEWPORT.width - x - 6, y - 6, 14, 8)
  screen.stroke()
end

--- Creates activity element to signify status of parameter.
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
-- @tparam state {number|boolean} 1 is active, 0 is inactive
function UI.signal(x, y, state)
  local r = 3
  screen.move(math.floor(x) + r, math.floor(y))
  screen.circle(math.floor(x), math.floor(y), r)

  if (state) then screen.fill()
  else screen.stroke() end
end

--- Draws value with label below it and optional signal.
-- Inactive cells hide their label and dim their value.
-- @tparam label {string}
-- @tparam value {string}
-- @tparam x {number}
-- @tparam y {number}
-- @tparam args {table}
-- @tparam args.active {boolean}  Optional; default true
-- @tparam args.signal {boolean}  Optional; draws signal when not nil
function UI.draw_cell(label, value, x, y, args)
  local is_active = args.active ~= false
  local g = UI.g

  screen.level(is_active and UI.ON or 0)
  screen.move(g(x), g(y + 10))
  screen.text(string.sub(label, 1, 6))

  screen.level(is_active and UI.ON or UI.OFF)
  if (args.signal ~= nil) then
    UI.signal(g(x + 3), g(y), args.signal)
    screen.move(g(x + 8), g(y + 2))
  else
    screen.move(g(x), g(y + 2))
  end
  screen.text(value)
end

--- Draws up to 4 cells across the screen, highlighting cells of current page.
-- @tparam cells {array}  each with `label`, `value`, `page` and optional `signal`
-- @tparam y {number}  Y-coordinate of the row
function UI.draw_row(cells, y)
  for i, cell in ipairs(cells) do
    UI.draw_cell(cell.label, cell.value, UI.COLUMNS[i], y, {
      active = UI.page_get() == cell.page,
      signal = cell.signal
    })
  end
end

--- Creates icon to show beat relative to interval.
-- Thenk you @itsyourbedtime for creating this for Takt!
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
-- @tparam tick {boolean}
function UI.metro_icon(x, y, tick)
  screen.move(x + 2, y + 5)
  screen.line(x + 7, y)
  screen.line(x + 12, y + 5)
  screen.line(x + 3, y + 5)
  screen.stroke()
  screen.move(x + 7, y + 3)
  screen.line(tick and (x + 4) or (x + 10), y)
  screen.stroke()
end

--- Creates recording indicator (e.g. circle).
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
function UI.recording(x, y)
  screen.move(math.floor(x) + 1, math.floor(y))
  screen.circle(math.floor(x), math.floor(y) - 3, 3)
  screen.fill()
end

--- Creates tape icon.
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
function UI.tape_icon(x, y)
  local r = 2

  screen.move(math.floor(x), math.floor(y) - 4)
  screen.line_rel(1, 0)
  screen.line_rel((r * 5), 0)

  for i = 0, 6, 2 do
    screen.move(math.floor(x) + (r * i), math.floor(y) - 4)
    screen.line_rel(0, 1)
    screen.line_rel(0, r)
  end

  screen.move(math.floor(x), math.floor(y) + (r * 2) - 4)
  screen.line_rel(1, 0)
  screen.line_rel(r, 0)
  screen.move(math.floor(x) + (r * 4), math.floor(y) + (r * 2) - 4)
  screen.line_rel(1, 0)
  screen.line_rel(r, 0)
  screen.stroke()
end

--- Creates speaker icon.
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
function UI.speaker_icon(x, y)
  screen.rect(x, y + 1, 2, 4)
  screen.fill()

  screen.move(x + 1, y + 2)
  screen.line_rel(4, -2)
  screen.line_rel(0, 6)
  screen.line_rel(-4, -2)
  screen.stroke()
end

--- Draws tempo indicator and value (page 0).
-- @tparam tempo {number}  BPM
-- @tparam tick {boolean}  metronome needle side
-- @tparam always_on {boolean}  true when BPM is set by E4 (Fates)
function UI.draw_tempo(tempo, tick, always_on)
  if always_on then screen.level(UI.ON)
  else UI.highlight({0}) end
  UI.metro_icon(UI.g(5), 5, tick)
  screen.move(UI.g(20), UI.g(10))
  screen.text(util.round(tempo))
end

--- Draws live/sample mode and output mode indicators.
-- @tparam args {table}
-- @tparam args.is_live {boolean}
-- @tparam args.is_recording {boolean}
-- @tparam args.has_sample {boolean}
-- @tparam args.output {string}  short output mode name, e.g. "MX"
-- @tparam args.output_page {number}  page that highlights the output mode
function UI.draw_mode(args)
  local center = UI.VIEWPORT.center
  local g = UI.g

  -- live input recording
  if args.is_live then
    screen.level(args.is_recording and UI.ON or UI.OFF)
    screen.move(center - g(15), g(10))
    screen.text("REC")
  end
  screen.level(args.is_live and UI.ON or UI.OFF)
  UI.recording(center - g(20), g(10))

  -- tape/sample input playback
  screen.level(args.is_live and UI.OFF or UI.ON)
  UI.tape_icon(center + g(10), g(10))

  if args.has_sample then
    screen.rect(center + g(8), g(4), 16, 8)
    screen.stroke()
  end

  -- output mode
  UI.highlight({args.output_page})
  UI.speaker_icon(g(88), 4)
  screen.move(g(96), g(10))
  screen.text(args.output)
end

--- Draws interval, gate, grid and offset markers.
-- Positions are in bars; at 1 bar or less the bar is drawn as a single
-- detailed bar, otherwise the full width is 4 bars.
-- @tparam args {table}
-- @tparam args.interval {table}  grid module drawing the interval
-- @tparam args.grid {table}  grid module drawing grid spans
-- @tparam args.y {number}  Y-coordinate of the bar
-- @tparam args.interval_len {number}
-- @tparam args.grid_len {number}
-- @tparam args.offset {number}
-- @tparam args.gate {number}
-- @tparam args.pos {number}  current grid step, from 1
-- @tparam args.is_detail {boolean}
-- @tparam args.is_repeating {boolean}  brightens current grid step
-- @tparam args.interval_label {string}
-- @tparam args.grid_label {string}
-- @tparam args.pages {table}  `interval` and `gate` page numbers to highlight
-- @treturn number  Y-coordinate below the grid label, for following rows
function UI.draw_bars(args)
  local g = UI.g
  local width = args.interval.ui.width
  local scale = args.is_detail and (width * 4) or width
  local div = args.is_detail and (args.interval_len / args.grid_len) or nil
  local interval_w = scale * args.interval_len / 4
  local offset_x = 2 + (scale * args.offset / 4)
  local grid_w = scale * args.grid_len / 4
  local label_y = args.y + args.grid.ui.height + 7

  -- gate length from offset, wrapping to the interval start
  local gate_w = math.min(scale * args.gate / 4, interval_w)
  UI.highlight({args.pages.gate}, UI.OFF, 1)
  args.grid.draw_span(g(offset_x), g(args.y), math.min(gate_w, 2 + interval_w - offset_x), nil, 2)
  if offset_x + gate_w > 2 + interval_w then
    args.grid.draw_span(g(2), g(args.y), offset_x + gate_w - interval_w - 2, nil, 2)
  end

  -- interval length marker(s)
  screen.level(2)
  if not args.is_detail then
    args.interval.draw(g(2), g(args.y), 4)
  end

  UI.highlight({args.pages.interval})
  args.interval.draw(g(2), g(args.y), div, g(interval_w))
  screen.move(g(interval_w), g(args.y - 3))
  screen.text_right(args.interval_label)

  -- grid length marker(s)
  if args.is_repeating then
    screen.level(UI.ON)
  else
    UI.highlight({args.pages.interval})
  end
  args.grid.draw_span(g(2 + ((args.pos - 1) * grid_w)), g(args.y), grid_w)

  -- offset marker, label kept on screen when the offset is past halfway
  UI.highlight({args.pages.interval})
  args.grid.draw_span(g(offset_x), g(args.y), grid_w)
  if offset_x > width / 2 then
    screen.move(g(offset_x + grid_w), g(label_y))
    screen.text_right(args.grid_label)
  else
    screen.move(g(offset_x), g(label_y))
    screen.text(args.grid_label)
  end

  return label_y
end

-- True on devices with a 4th encoder (Fates). norns.encoders.accel always has
-- 4 entries on current firmware, so check for the knob's input device instead.
UI.HAS_E4 = string.find(
  util.os_capture("cat /sys/class/input/*/device/name 2>/dev/null", true) or "",
  "knob4") ~= nil

-- Page 0 (BPM) is only needed on 3 encoder devices, Fates sets BPM with E4.
if UI.HAS_E4 then
  UI.FIRST_PAGE = 1
end

return UI
