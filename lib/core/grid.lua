local Grid = {
  name = "Grid",
  index = 0,
  sum = 0,
  pos = 0,
  ui = {
    height = 14,
    width = 124 -- divides evenly by 4
  }
}

--- Add params for Grid
-- @tparam options {array}
-- @tparam default_val {number}
function Grid.add_params(options, default_val) 
  params:add_option(string.lower(Grid.name), Grid.name, options, default_val)
  params:set_action(string.lower(Grid.name), Grid.update)
end

--- Gets Grid parameter value
function Grid.get()
  return params:get(string.lower(Grid.name))  
end

--- Sets Grid parameter value
-- @tparam val {number}
function Grid.set(val)
  params:set(string.lower(Grid.name), (val or Grid.index))  
end

--- Sets Grid parameter value as delta
-- @tparam val {number}
function Grid.delta(val)
  params:delta(string.lower(Grid.name), val)
end

--- Increments grid sum.
-- @tparam inc {number}  increment amount
function Grid.increment_sum(inc)
  Grid.sum = Grid.sum + inc
end

--- Increments grid pos(ition).
-- @tparam inc {number}  increment amount
function Grid.increment_pos(inc)
  Grid.pos = Grid.pos + (inc or 1)
end
  
--- Resets grid sum.
function Grid.reset_sum() 
  Grid.sum = 0
  Grid.pos = 0
end

--- Handler for updates.
-- @tparam val {number}
function Grid.update(val) end

--- Draws stroked rectangle with optional divisions
-- @tparam x {number}
-- @tparam y {number}
-- @tparam div {number}  number of divisions
-- @tparam w {number}  width
-- @tparam h {number}  height
function Grid.draw(x, y, div, w, h)
  screen.rect(x, y, (w or Grid.ui.width), (h or Grid.ui.height))
  if (div ~= nil and div > 0) then
    -- screen.level(2)
    for i = 1, (div - 1) do
      screen.move(x + ((w or Grid.ui.width) / div) * i, y)
      screen.line_rel(0, (h or Grid.ui.height))
    end
  end
  screen.stroke()
end

--- Draws dot textured "span" rectangle.
-- @tparam x {number}
-- @tparam y {number}
-- @tparam w {number}  width
-- @tparam h {number}  height
-- @tparam pad {number}  spacing between dots; default 2
function Grid.draw_span(x, y, w, h, pad)
  screen.move(x, y)
  for x_ = 0, (w or Grid.ui.width), (pad or 2) do
    for y_ = -2, (h or Grid.ui.height), (pad or 2) do 
      screen.pixel(x + x_, y + y_)
    end
  end
  screen.fill() 
end

return Grid