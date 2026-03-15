-- grainrungler.lua v2
-- sample-based benjolin with true phase modulation
-- SC engine: BufRd granular + shift register + twin peak + comb + delay

engine.name = "GrainRungler"

local UI = include("grainrungler/lib/ui")
local clocks = {}

local PP = {
  [1] = { -- GRAINS
    {"pos_a","pos A"},{"rate_a","rate A"},{"grain_a","grain A"},{"level_a","lvl A"},
    {"atk_a","atk A"},{"rel_a","rel A"},
    {"jitter_a","jit A"},{"density_a","den A"},
    {"pos_b","pos B"},{"rate_b","rate B"},{"grain_b","grain B"},{"level_b","lvl B"},
    {"atk_b","atk B"},{"rel_b","rel B"},
    {"jitter_b","jit B"},{"density_b","den B"},
    {"spread","spread"},
  },
  [2] = { -- RUNGLER
    {"run_a","Run A"},{"run_b","Run B"},{"run_f","Run F"},
    {"chaos","chaos"},{"loop_len","length"},{"gate_thresh","gate"},
  },
  [3] = { -- CROSS-MOD
    {"xmod_pm_ab","A>B phase"},{"xmod_pm_ba","B>A phase"},
    {"xmod_amp_ab","A>B amp"},{"xmod_amp_ba","B>A amp"},
  },
  [4] = { -- FILTER
    {"filt_freq","cutoff"},{"filt_res","res"},
    {"filt_type","type"},{"filt_peak2","peak2"},{"filt_mix","filt mix"},
    {"comb_freq","comb Hz"},{"comb_fb","comb fb"},{"comb_mix","comb mix"},
  },
  [5] = { -- FX
    {"dly_time","delay"},{"dly_fb","dly fb"},{"dly_mix","dly mix"},{"cv_dly","cv>dly"},
    {"pan_mode","pan mode"},{"pan_width","pan width"},
    {"amp","volume"},
  },
}
local sel = {1,1,1,1,1}
local poll_rung, poll_amp = 0, 0

function init()
  params:add_separator("gr_h","g r a i n r u n g l e r")

  -- rungler
  params:add_separator("gr_r","rungler")
  params:add_control("run_a","Run A",controlspec.new(0,2,'lin',0,0.5,''))
  params:set_action("run_a",function(v) engine.run_a(v) end)
  params:add_control("run_b","Run B",controlspec.new(0,2,'lin',0,0.3,''))
  params:set_action("run_b",function(v) engine.run_b(v) end)
  params:add_control("run_f","Run F",controlspec.new(0,2,'lin',0,0.4,''))
  params:set_action("run_f",function(v) engine.run_f(v) end)
  params:add_control("chaos","chaos",controlspec.new(0,1,'lin',0,1,''))
  params:set_action("chaos",function(v) engine.chaos(v) end)
  params:add_number("loop_len","register len",3,8,8)
  params:set_action("loop_len",function(v) engine.loop_len(v) end)
  params:add_control("gate_thresh","gate",controlspec.new(-1,1,'lin',0,0.3,''))
  params:set_action("gate_thresh",function(v) engine.gate_thresh(v) end)

  -- sample A
  params:add_separator("gr_a","sample A (data)")
  params:add_file("sample_a","sample A",_path.audio)
  params:set_action("sample_a",function(v)
    if v and v~="" and v~=_path.audio then engine.load_a(v) end
  end)
  params:add_control("pos_a","position",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("pos_a",function(v) engine.pos_a(v) end)
  params:add_control("rate_a","rate",controlspec.new(-4,4,'lin',0,1,'x'))
  params:set_action("rate_a",function(v) engine.rate_a(v) end)
  params:add_control("grain_a","grain size",controlspec.new(0.02,2,'exp',0,0.12,'s'))
  params:set_action("grain_a",function(v) engine.grain_a(v) end)
  params:add_control("level_a","level",controlspec.new(0,1,'lin',0,0.8,''))
  params:set_action("level_a",function(v) engine.level_a(v) end)
  params:add_control("atk_a","attack",controlspec.new(0.001,0.5,'exp',0,0.01,'s'))
  params:set_action("atk_a",function(v) engine.atk_a(v) end)
  params:add_control("rel_a","release",controlspec.new(0.001,0.5,'exp',0,0.05,'s'))
  params:set_action("rel_a",function(v) engine.rel_a(v) end)
  params:add_control("jitter_a","jitter",controlspec.new(0,500,'lin',0,0,'ms'))
  params:set_action("jitter_a",function(v) engine.jitter_a(v) end)
  params:add_control("density_a","density",controlspec.new(1,200,'exp',0,20,'Hz'))
  params:set_action("density_a",function(v) engine.density_a(v) end)

  -- sample B
  params:add_separator("gr_b","sample B (clock)")
  params:add_file("sample_b","sample B",_path.audio)
  params:set_action("sample_b",function(v)
    if v and v~="" and v~=_path.audio then engine.load_b(v) end
  end)
  params:add_control("pos_b","position",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("pos_b",function(v) engine.pos_b(v) end)
  params:add_control("rate_b","rate",controlspec.new(-4,4,'lin',0,0.25,'x'))
  params:set_action("rate_b",function(v) engine.rate_b(v) end)
  params:add_control("grain_b","grain size",controlspec.new(0.02,2,'exp',0,0.2,'s'))
  params:set_action("grain_b",function(v) engine.grain_b(v) end)
  params:add_control("level_b","level",controlspec.new(0,1,'lin',0,0.8,''))
  params:set_action("level_b",function(v) engine.level_b(v) end)
  params:add_control("atk_b","attack",controlspec.new(0.001,0.5,'exp',0,0.01,'s'))
  params:set_action("atk_b",function(v) engine.atk_b(v) end)
  params:add_control("rel_b","release",controlspec.new(0.001,0.5,'exp',0,0.05,'s'))
  params:set_action("rel_b",function(v) engine.rel_b(v) end)
  params:add_control("jitter_b","jitter",controlspec.new(0,500,'lin',0,0,'ms'))
  params:set_action("jitter_b",function(v) engine.jitter_b(v) end)
  params:add_control("density_b","density",controlspec.new(1,200,'exp',0,20,'Hz'))
  params:set_action("density_b",function(v) engine.density_b(v) end)

  -- cross-mod
  params:add_separator("gr_x","cross-modulation")
  params:add_control("xmod_pm_ab","A>B phase mod",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("xmod_pm_ab",function(v) engine.xmod_pm_ab(v) end)
  params:add_control("xmod_pm_ba","B>A phase mod",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("xmod_pm_ba",function(v) engine.xmod_pm_ba(v) end)
  params:add_control("xmod_amp_ab","A>B amp mod",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("xmod_amp_ab",function(v) engine.xmod_amp_ab(v) end)
  params:add_control("xmod_amp_ba","B>A amp mod",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("xmod_amp_ba",function(v) engine.xmod_amp_ba(v) end)

  -- filter
  params:add_separator("gr_f","filter")
  params:add_control("filt_freq","cutoff",controlspec.new(20,20000,'exp',0,2000,'Hz'))
  params:set_action("filt_freq",function(v) engine.filt_freq(v) end)
  params:add_control("filt_res","resonance",controlspec.new(0.05,2,'lin',0,0.5,''))
  params:set_action("filt_res",function(v) engine.filt_res(v) end)
  params:add_option("filt_type","type",{"LP","BP","HP","twin peak"},1)
  params:set_action("filt_type",function(v) engine.filt_type(v-1) end)
  params:add_control("filt_peak2","peak2 ratio",controlspec.new(0.5,4,'exp',0,1.5,'x'))
  params:set_action("filt_peak2",function(v) engine.filt_peak2(v) end)
  params:add_control("filt_mix","filter mix",controlspec.new(0,1,'lin',0,0.8,''))
  params:set_action("filt_mix",function(v) engine.filt_mix(v) end)

  -- comb
  params:add_separator("gr_comb","comb filter")
  params:add_control("comb_freq","comb freq",controlspec.new(20,2000,'exp',0,200,'Hz'))
  params:set_action("comb_freq",function(v) engine.comb_freq(v) end)
  params:add_control("comb_fb","comb feedback",controlspec.new(0,0.95,'lin',0,0,''))
  params:set_action("comb_fb",function(v) engine.comb_fb(v) end)
  params:add_control("comb_mix","comb mix",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("comb_mix",function(v) engine.comb_mix(v) end)

  -- fx
  params:add_separator("gr_fx","delay & pan")
  params:add_control("dly_time","delay time",controlspec.new(0,2,'lin',0,0,'s'))
  params:set_action("dly_time",function(v) engine.dly_time(v) end)
  params:add_control("dly_fb","delay fb",controlspec.new(0,0.9,'lin',0,0,''))
  params:set_action("dly_fb",function(v) engine.dly_fb(v) end)
  params:add_control("dly_mix","delay mix",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("dly_mix",function(v) engine.dly_mix(v) end)
  params:add_control("cv_dly","cv > delay",controlspec.new(0,2,'lin',0,0,''))
  params:set_action("cv_dly",function(v) engine.cv_dly(v) end)
  params:add_option("pan_mode","pan mode",{"static","rungler","random"},1)
  params:set_action("pan_mode",function(v) engine.pan_mode(v-1) end)
  params:add_control("pan_width","pan width",controlspec.new(0,1,'lin',0,0.5,''))
  params:set_action("pan_width",function(v) engine.pan_width(v) end)

  params:add_control("spread","spread",controlspec.new(0,1,'lin',0,0.5,''))
  params:set_action("spread",function(v) engine.spread(v) end)
  params:add_control("amp","volume",controlspec.new(0,1,'lin',0,0.8,''))
  params:set_action("amp",function(v) engine.amp(v) end)

  UI.init(PP, sel)

  local pr = poll.set("poll_rung")
  pr.callback = function(v) poll_rung=v; UI.poll_rung=v end
  pr.time=1/30; pr:start()
  local pa = poll.set("poll_amp")
  pa.callback = function(v) poll_amp=v; UI.poll_amp=v end
  pa.time=1/30; pa:start()
  clocks.polls = {pr, pa}

  clocks[1] = clock.run(function()
    while true do clock.sleep(1/15); UI.push_scope(poll_rung); redraw() end
  end)

  params:bang()
end

function enc(n, d)
  if n==1 then
    if UI.k1_held then UI.page=util.clamp(UI.page+d,1,UI.NUM_PAGES)
    else
      local list=PP[UI.page]
      if list then sel[UI.page]=util.clamp(sel[UI.page]+d,1,#list) end
    end
  elseif n==2 then
    local list=PP[UI.page]
    if list and list[sel[UI.page]] then params:delta(list[sel[UI.page]][1],d) end
  elseif n==3 then
    local list=PP[UI.page]; local ni=sel[UI.page]+1
    if list and list[ni] then params:delta(list[ni][1],d) end
  end
end

function key(n, z)
  if n==1 then UI.k1_held=(z==1)
  elseif n==2 and z==1 then UI.sel_smp=UI.sel_smp=="A" and "B" or "A"
  elseif n==3 and z==1 then
    if UI.page==1 then
      fileselect.enter(_path.audio, function(p)
        if p and p~="cancel" then params:set("sample_"..string.lower(UI.sel_smp),p) end
      end)
    else
      local list=PP[UI.page]
      if list then for _,e in ipairs(list) do
        local p=params:lookup_param(e[1])
        if p and p.t==3 then params:set_raw(e[1],math.random()) end
      end end
    end
  end
end

function redraw() UI.draw() end
function cleanup()
  for _,id in ipairs(clocks) do if id then clock.cancel(id) end end
  if clocks.polls then for _,p in ipairs(clocks.polls) do p:stop() end end
end
