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
  LAST_PAGE = 3
}

function init()
  
end

--- Track position of metronome pointer
-- @private
local metro_pos_ = false

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
-- @tparam glitch_func {function}  Optional function to pass for "glitching" position
function UI.page_marker(x, y, param_str, glitch_func)
  screen.move((UI.VIEWPORT.width - x) * (glitch_func() or 1), y * (glitch_func() or 1))
  screen.text_center("P" .. param_str)
  screen.line_width(1)
  -- TODO(frederickk): this implementation is fragile.
  screen.rect(UI.VIEWPORT.width - x - 6, y - 6, x + 2, y - 0)
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

--- Creates icon to show beat relative to interval.
-- Thenk you @itsyourbedtime for creating this for Takt!
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
-- @tparam phase {number}
function UI.metro_icon(x, y, phase)
  screen.move(x + 2, y + 5)
  screen.line(x + 7, y)
  screen.line(x + 12, y + 5)
  screen.line(x + 3, y + 5)
  screen.stroke()
  screen.move(x + 7, y + 3)
  screen.line(metro_pos_ and (x + 4) or (x + 10), y )
  screen.stroke()

  if (phase == 0) then metro_pos_ = not metro_pos_ end
end

-- Default, page 0 is reserved for handling any E4 Fates
-- for genuine 3 encoder Norns devices.
if (#norns.encoders.accel == 4) then
  UI.FIRST_PAGE = 1
end

return UI
