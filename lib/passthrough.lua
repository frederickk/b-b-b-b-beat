-- passthrough
--
-- library for passing midi
-- from device to an interface
-- + clocking from interface
-- + scale quantizing
-- + user event callbacks
--
-- for how to use see example
--
-- PRs welcome

local Passthrough = {}
local tab = require "tabutil"
local MusicUtil = require "musicutil"
local devices = {}
local midi_device
local midi_output
local clock_device
local quantize_midi
local scale_names = {}
local current_scale = {}
local midi_notes = {}


function Passthrough.user_device_event(data) end

function Passthrough.user_output_event(data) end

function Passthrough.device_event(data)
  if #data == 0 then
    return
  end
  local msg = midi.to_msg(data)
  local dev_channel_param = params:get("device_channel")
  local dev_chan = dev_channel_param > 1 and (dev_channel_param - 1) or msg.ch

  local out_ch_param = params:get("output_channel")
  local out_ch = out_ch_param > 1 and (out_ch_param - 1) or msg.ch

  if msg and msg.ch == dev_chan then
    local note = msg.note

    if msg.note ~= nil then
      if quantize_midi == true then
        note = MusicUtil.snap_note_to_array(note, current_scale)
      end
    end

    if msg.type == "note_off" then
      midi_output:note_off(note, 0, out_ch)
    elseif msg.type == "note_on" then
      midi_output:note_on(note, msg.vel, out_ch)
    elseif msg.type == "key_pressure" then
      midi_output:key_pressure(note, msg.val, out_ch)
    elseif msg.type == "channel_pressure" then
      midi_output:channel_pressure(msg.val, out_ch)
    elseif msg.type == "pitchbend" then
      midi_output:pitchbend(msg.val, out_ch)
    elseif msg.type == "program_change" then
      midi_output:program_change(msg.val, out_ch)
    elseif msg.type == "cc" then
      midi_output:cc(msg.cc, msg.val, out_ch)
    -- elseif msg.type == "clock" then
    --   midi_output:clock() 
    -- elseif msg.type == "start" then
    --   midi_output:start()
    -- elseif msg.type == "stop" then
    --   midi_output:stop()
    -- elseif msg.type == "continue" then
    --   midi_output:continue()
    end
  end
  
  Passthrough.user_device_event(data)
end

function Passthrough.output_event(data)
  if clock_device == false then
    return
  else
    local msg = midi.to_msg(data)
    local note = msg.note
    
    if msg.type == "clock" then
      midi_device:clock()
    elseif msg.type == "start" then
      midi_device:start()
    elseif msg.type == "stop" then
      midi_device:stop()
    elseif msg.type == "continue" then
      midi_device:continue()
--     elseif msg.type == "note_off" then
--       midi_device:note_off(note, 0, out_ch)
--     elseif msg.type == "note_on" then
--       midi_device:note_on(note, msg.vel, out_ch)
--     elseif msg.type == "key_pressure" then
--       midi_device:key_pressure(note, msg.val, out_ch)
--     elseif msg.type == "channel_pressure" then
--       midi_device:channel_pressure(msg.val, out_ch)
--     elseif msg.type == "pitchbend" then
--       midi_device:pitchbend(msg.val, out_ch)
--     elseif msg.type == "program_change" then
--       midi_device:program_change(msg.val, out_ch)
--     elseif msg.type == "cc" then
--       midi_device:cc(msg.cc, msg.val, )
    end
  end
  
  Passthrough.user_output_event(data)
end

function Passthrough.build_scale()
  current_scale = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 128)
end

function Passthrough.get_midi_devices()
  d = {}
  for id, device in pairs(midi.vports) do
    d[id] = device.name
  end
  return d
end

function Passthrough.init()
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
  end

  clock_device = false
  quantize_midi = false

  midi_device = midi.connect(1)
  midi_device.event = Passthrough.device_event  
  midi_output = midi.connect(2)
  midi_output.event = Passthrough.output_event

  devices = Passthrough.get_midi_devices()

  params:add_group("PASSTHROUGH", 8)
  params:add_option("midi_device", "Device", devices, 1) -- Value is actually 0 
  params:set_action("midi_device", function(value)
      midi_device.event = nil
      midi_device = midi.connect(value)
      midi_device.event = Passthrough.device_event
    end)

  params:add_option("midi_output", "Out", devices, 2)
  params:set_action("midi_output", function(value)
      midi_output.event = nil
      midi_output = midi.connect(value)
      midi_output.event = Passthrough.output_event
    end)

  local channels = {"No change"}
  for i = 1, 16 do
    table.insert(channels, i)
  end
  params:add_option("device_channel", "Device channel", channels, 1)

  channels[1] = "Device src."
  params:add_option("output_channel", "Out channel", channels, 1)

  params:add_option("clock_device", "Clock device", {"no", "yes"})
  params:set_action("clock_device", function(value)
      clock_device = value == 2
      if value == 1 then
        midi_device:stop()
      end
    end)

  params:add_option("quantize_midi", "Quantize", {"no", "yes"})
  params:set_action("quantize_midi", function(value)
      quantize_midi = value == 2
      Passthrough.build_scale()
    end)

  params:add_option("scale_mode", "Scale", scale_names, 5)
  params:set_action("scale_mode", function()
      Passthrough.build_scale()
    end)

  params:add_number("root_note", "Root", 0, 11, 0, function(param)
      return MusicUtil.note_num_to_name(param:get())
    end)
  params:set_action("root_note", function()
      Passthrough.build_scale()
    end)

  Passthrough.device = midi_device
  Passthrough.output = midi_output
end

return Passthrough
