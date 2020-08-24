local Interval = {
  name = "Interval",
  index = 0,
  sum = 0,
  pos = 0,
  ui = {
    height = 14,
    width = 124 -- divides evenly by 4
  }
}

--- Add params for Interval
-- @param options table:
-- @param default_val number:
function Interval.add_params(options, default_val) 
  params:add_option(string.lower(Interval.name), Interval.name, options, default_val)
  params:set_action(string.lower(Interval.name), Interval.update)
end

--- Gets Interval parameter value
-- @return number: interval (index) parameter value
function Interval.get()
  return params:get(string.lower(Interval.name))  
end

--- Sets Interval parameter value
-- @param val number:
function Interval.set(val)
  params:set(string.lower(Interval.name), (val or Interval.index))  
end

--- Sets Interval parameter value as delta
-- @param val number:
function Interval.delta(val)
  params:delta(string.lower(Interval.name), val)
end

--- Increments Interval sum.
-- @param inc number:  increment amount
function Interval.increment_sum(inc)
  Interval.sum = Interval.sum + inc
end

--- Increments Interval pos(ition).
-- @param inc number:  increment amount
function Interval.increment_pos(inc)
  Interval.pos = Interval.pos + (inc or 1)
end
  
--- Resets Interval sum.
function Interval.reset_sum() 
  Interval.sum = 0
  Interval.pos = 0
end

--- Handler for updates.
-- @param val number:
function Interval.update(val) end

--- Draws stroked rectangle with optional divisions
-- @param x number:
-- @param y number:
-- @param div number:  number of divisions
-- @param w number:  width
-- @param h number:  height
function Interval.draw(x, y, div, w, h)
  screen.rect(x, y, (w or Interval.ui.width), (h or Interval.ui.height))
  if (div ~= nil and div > 0) then
    -- screen.level(2)
    for i = 1, (div - 1) do
      screen.move(x + ((w or Interval.ui.width) / div) * i, y)
      screen.line_rel(0, (h or Interval.ui.height))
    end
  end
  screen.stroke()
end

--- Draws dot textured "span" rectangle.
-- @param x number:
-- @param y number:
-- @param w number:  width
-- @param h number:  height
-- @param pad number:  spacing between dots; default 2
function Interval.draw_span(x, y, w, h, pad)
  screen.move(x, y)
  for x_ = 0, (w or Interval.ui.width), (pad or 2) do
    for y_ = -2, (h or Interval.ui.height), (pad or 2) do 
      screen.pixel(x + x_, y + y_)
    end
  end
  screen.fill() 
end

return Interval