-- grainrungler.lua
-- sample-based benjolin. pure softcut + Lua.
-- no SC engine needed.
--
-- E1: scroll params (K1+E1: page)
-- E2: selected param, E3: next param
-- K2 short: toggle A/B, K2 long: stop rec
-- K3: load/randomize, K1+K3: record

local Rungler = include("grainrungler/lib/rungler")
local Grains  = include("grainrungler/lib/grains")
local UI      = include("grainrungler/lib/ui")
local clocks = {}

local PAGE_PARAMS = {
  [1] = { -- GRAINS
    {"pos_a","pos A"},{"rate_a","rate A"},{"grain_a","grain A"},{"level_a","lvl A"},
    {"atk_a","atk A"},{"rel_a","rel A"},
    {"pos_b","pos B"},{"rate_b","rate B"},{"grain_b","grain B"},{"level_b","lvl B"},
    {"atk_b","atk B"},{"rel_b","rel B"},
    {"spread","spread"},
  },
  [2] = { -- RUNGLER
    {"run_a","Run A"},{"run_b","Run B"},{"run_f","Run F"},
    {"chaos","chaos"},{"loop_len","length"},
    {"source_mix","source"},{"osc_a","int A"},{"osc_b","int B"},
    {"gate_thresh","gate"},
  },
  [3] = { -- FILTER
    {"filt_freq","cutoff"},{"filt_res","res"},{"filt_type","type"},{"filt_mix","mix"},
  },
  [4] = { -- FX
    {"xmod_ab","A>B xmod"},{"xmod_ba","B>A xmod"},
    {"dly_time","delay"},{"dly_fb","dly fb"},{"dly_send","dly send"},{"cv_dly","cv>dly"},
  },
}
local sel = {1,1,1,1}

function init()
  params:add_separator("gr_h","g r a i n r u n g l e r")

  -- rungler
  params:add_separator("gr_r","rungler")
  params:add_control("run_a","Run A",controlspec.new(0,2,'lin',0,0.5,''))
  params:set_action("run_a",function(v) Rungler.run_a=v end)
  params:add_control("run_b","Run B",controlspec.new(0,2,'lin',0,0.3,''))
  params:set_action("run_b",function(v) Rungler.run_b=v end)
  params:add_control("run_f","Run F",controlspec.new(0,2,'lin',0,0.4,''))
  params:set_action("run_f",function(v) Rungler.run_f=v end)
  params:add_control("chaos","chaos",controlspec.new(0,1,'lin',0,1,''))
  params:set_action("chaos",function(v) Rungler.chaos=v end)
  params:add_number("loop_len","register length",3,8,8)
  params:set_action("loop_len",function(v) Rungler.loop_len=v end)
  params:add_control("gate_thresh","gate",controlspec.new(-1,1,'lin',0,0.3,''))
  params:set_action("gate_thresh",function(v) Rungler.gate_thresh=v end)
  params:add_control("source_mix","source mix",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("source_mix",function(v) Rungler.source_mix=v end)
  params:add_control("osc_a","int osc A",controlspec.new(0.05,100,'exp',0,4,'Hz'))
  params:set_action("osc_a",function(v) Rungler.freq_a=v end)
  params:add_control("osc_b","int osc B",controlspec.new(0.05,100,'exp',0,0.5,'Hz'))
  params:set_action("osc_b",function(v) Rungler.freq_b=v end)

  -- sample A
  params:add_separator("gr_a","sample A (data)")
  params:add_file("sample_a","sample A",_path.audio)
  params:set_action("sample_a",function(v) Grains.load_sample("A",v) end)
  params:add_control("pos_a","position A",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("pos_a",function(v) Grains.A.position=v end)
  params:add_control("rate_a","rate A",controlspec.new(-4,4,'lin',0,1,'x'))
  params:set_action("rate_a",function(v) Grains.A.rate=v end)
  params:add_control("grain_a","grain A",controlspec.new(0.02,2,'exp',0,0.12,'s'))
  params:set_action("grain_a",function(v) Grains.A.grain_size=v end)
  params:add_control("level_a","level A",controlspec.new(0,1,'lin',0,0.8,''))
  params:set_action("level_a",function(v) Grains.A.level=v end)
  params:add_control("atk_a","attack A",controlspec.new(0.001,0.5,'exp',0,0.01,'s'))
  params:set_action("atk_a",function(v) Grains.A.attack=v end)
  params:add_control("rel_a","release A",controlspec.new(0.001,0.5,'exp',0,0.05,'s'))
  params:set_action("rel_a",function(v) Grains.A.release=v end)

  -- sample B
  params:add_separator("gr_b","sample B (clock)")
  params:add_file("sample_b","sample B",_path.audio)
  params:set_action("sample_b",function(v) Grains.load_sample("B",v) end)
  params:add_control("pos_b","position B",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("pos_b",function(v) Grains.B.position=v end)
  params:add_control("rate_b","rate B",controlspec.new(-4,4,'lin',0,0.25,'x'))
  params:set_action("rate_b",function(v) Grains.B.rate=v end)
  params:add_control("grain_b","grain B",controlspec.new(0.02,2,'exp',0,0.2,'s'))
  params:set_action("grain_b",function(v) Grains.B.grain_size=v end)
  params:add_control("level_b","level B",controlspec.new(0,1,'lin',0,0.8,''))
  params:set_action("level_b",function(v) Grains.B.level=v end)
  params:add_control("atk_b","attack B",controlspec.new(0.001,0.5,'exp',0,0.01,'s'))
  params:set_action("atk_b",function(v) Grains.B.attack=v end)
  params:add_control("rel_b","release B",controlspec.new(0.001,0.5,'exp',0,0.05,'s'))
  params:set_action("rel_b",function(v) Grains.B.release=v end)

  -- filter
  params:add_separator("gr_f","filter")
  params:add_control("filt_freq","cutoff",controlspec.new(40,18000,'exp',0,4000,'Hz'))
  params:set_action("filt_freq",function(v) Grains.filter_freq=v end)
  params:add_control("filt_res","resonance",controlspec.new(0.2,4,'lin',0,2,''))
  params:set_action("filt_res",function(v) Grains.filter_res=v end)
  params:add_option("filt_type","type",{"LP","BP","HP"},1)
  params:set_action("filt_type",function(v) Grains.filter_type=v end)
  params:add_control("filt_mix","filter mix",controlspec.new(0,1,'lin',0,0.8,''))
  params:set_action("filt_mix",function(v) Grains.filter_mix=v end)

  -- cross-mod + delay
  params:add_separator("gr_x","cross-mod & delay")
  params:add_control("xmod_ab","A > B xmod",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("xmod_ab",function(v) Grains.xmod_a_to_b=v end)
  params:add_control("xmod_ba","B > A xmod",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("xmod_ba",function(v) Grains.xmod_b_to_a=v end)
  params:add_control("dly_time","delay time",controlspec.new(0,4,'lin',0,0,'s'))
  params:set_action("dly_time",function(v) Grains.delay_time=v end)
  params:add_control("dly_fb","delay fb",controlspec.new(0,0.9,'lin',0,0,''))
  params:set_action("dly_fb",function(v) Grains.delay_fb=v end)
  params:add_control("dly_send","delay send",controlspec.new(0,1,'lin',0,0.3,''))
  params:set_action("dly_send",function(v) Grains.delay_send=v end)
  params:add_control("cv_dly","cv > delay",controlspec.new(0,2,'lin',0,0,''))
  params:set_action("cv_dly",function(v) Grains.cv_to_delay=v end)

  params:add_control("spread","spread",controlspec.new(0,1,'lin',0,0.5,''))
  params:set_action("spread",function(v) Grains.spread=v end)

  Grains.init(Rungler)
  UI.init(Rungler, Grains, PAGE_PARAMS, sel)

  clocks[1] = clock.run(function()
    local dt = 1/120
    while true do
      clock.sleep(dt)
      Rungler.clock_tick(Grains.get_data_pulse(), Grains.get_clock_pulse(), dt)
      Grains.update(dt)
      UI.push_scope(Rungler.cv, Rungler.tri_a)
    end
  end)

  clocks[2] = clock.run(function()
    while true do clock.sleep(1/15); redraw() end
  end)

  params:bang()
end

function enc(n, d)
  if n == 1 then
    if UI.k1_held then
      UI.page = util.clamp(UI.page + d, 1, UI.NUM_PAGES)
    else
      local list = PAGE_PARAMS[UI.page]
      if list then sel[UI.page] = util.clamp(sel[UI.page] + d, 1, #list) end
    end
  elseif n == 2 then
    local list = PAGE_PARAMS[UI.page]
    if list and list[sel[UI.page]] then params:delta(list[sel[UI.page]][1], d) end
  elseif n == 3 then
    local list = PAGE_PARAMS[UI.page]
    local ni = sel[UI.page] + 1
    if list and list[ni] then params:delta(list[ni][1], d) end
  end
end

local k2_time = 0
function key(n, z)
  if n == 1 then UI.k1_held = (z == 1)
  elseif n == 2 then
    if z == 1 then k2_time = util.time()
    else
      if util.time() - k2_time > 0.5 then
        if Grains.recording then Grains.stop_rec() end
      else UI.sel_smp = UI.sel_smp == "A" and "B" or "A" end
    end
  elseif n == 3 and z == 1 then
    if UI.k1_held then
      if Grains.recording then Grains.stop_rec()
      else Grains.start_rec(UI.sel_smp) end
    elseif UI.page == 1 then
      fileselect.enter(_path.audio, function(p)
        if p and p ~= "cancel" then
          params:set("sample_"..string.lower(UI.sel_smp), p)
        end
      end)
    else
      local list = PAGE_PARAMS[UI.page]
      if list then
        for _, e in ipairs(list) do
          local p = params:lookup_param(e[1])
          if p and p.t == 3 then params:set_raw(e[1], math.random()) end
        end
      end
    end
  end
end

function redraw() UI.draw() end
function cleanup()
  for _,id in ipairs(clocks) do if id then clock.cancel(id) end end
  Grains.cleanup()
end
