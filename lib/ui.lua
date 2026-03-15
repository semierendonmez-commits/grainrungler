-- lib/ui.lua
-- grainrungler UI: 4 pages, E1 scroll

local UI = {}
local PP, SEL

UI.page = 1; UI.NUM_PAGES = 4
UI.PAGE_NAMES = {"GRAINS","RUNGLER","FILTER","FX"}
UI.sel_smp = "A"; UI.k1_held = false
UI.poll_rung = 0; UI.poll_amp = 0

UI.scope_size = 100
UI.scope = {x={},idx=1,len=0}
for i=1,100 do UI.scope.x[i]=0 end
function UI.push_scope(x)
  UI.scope.x[UI.scope.idx]=x
  UI.scope.idx=(UI.scope.idx%UI.scope_size)+1
  if UI.scope.len<UI.scope_size then UI.scope.len=UI.scope.len+1 end
end

local wf={A={pts={},p=""},B={pts={},p=""}}
local function gen_wf(path,n)
  local pts={}; local h=0
  for i=1,#path do h=(h*31+string.byte(path,i))%99991 end
  math.randomseed(h)
  for i=1,n do pts[i]=(math.random()*2-1)*0.6+math.sin(i/n*math.pi*3+h*0.007)*0.4 end
  math.randomseed(os.time()); return pts
end

function UI.init(pp,s) PP=pp; SEL=s end

function UI.draw()
  screen.clear()
  for i=1,UI.NUM_PAGES do
    screen.level(i==UI.page and 15 or 3)
    screen.rect(2+(i-1)*7,1,4,4)
    if i==UI.page then screen.fill() else screen.stroke() end
  end
  screen.level(10); screen.font_size(8)
  screen.move(34,7); screen.text(UI.PAGE_NAMES[UI.page])
  -- amp bar
  local aw=math.floor(UI.poll_amp*18)
  if aw>0 then
    screen.level(math.floor(3+UI.poll_amp*10))
    screen.rect(100,2,aw,3); screen.fill()
  end
  screen.level(1); screen.move(0,9); screen.line(128,9); screen.stroke()
  local fn={UI.draw_grains,UI.draw_rungler,UI.draw_filter,UI.draw_fx}
  fn[UI.page]()
  UI.draw_footer()
  screen.update()
end

function UI.draw_footer()
  screen.level(1); screen.move(0,52); screen.line(128,52); screen.stroke()
  screen.font_size(8)
  local list=PP[UI.page]; if not list then return end
  local si=SEL[UI.page]; local e=list[si]
  if e then
    screen.level(10); screen.move(2,59); screen.text("E2:"..e[2])
    screen.level(15); screen.move(2,64); screen.text(params:string(e[1]))
  end
  local ne=list[si+1]
  if ne then
    screen.level(5); screen.move(68,59); screen.text("E3:"..ne[2])
    screen.level(10); screen.move(68,64); screen.text(params:string(ne[1]))
  end
end

-- ── GRAINS ──────────────────────────────────────────────
function UI.draw_grains()
  screen.level(2); screen.move(64,9); screen.line(64,52); screen.stroke()
  for _,id in ipairs({"A","B"}) do
    local ox=id=="A" and 0 or 66
    local is_sel=(UI.sel_smp==id)
    local pre=string.lower(id)

    -- get param values
    local pos=params:get("pos_"..pre)
    local rate=params:get("rate_"..pre)
    local gs=params:get("grain_"..pre)
    local lvl=params:get("level_"..pre)
    local path_val=params:get("sample_"..pre)
    local loaded=(path_val and path_val ~= "" and path_val ~= _path.audio)

    screen.level(is_sel and 15 or 5); screen.font_size(8)
    screen.move(ox+2,17); screen.text(id)
    screen.level(loaded and 7 or 2); screen.move(ox+10,17)
    if loaded then
      local name = path_val:match("[^/]+$") or "?"
      screen.text(string.sub(name, 1, 7))
    else screen.text("---") end

    -- waveform
    local wy,ww=30,50
    if loaded then
      if wf[id].p ~= path_val then wf[id].pts=gen_wf(path_val,ww); wf[id].p=path_val end
      screen.level(is_sel and 7 or 4)
      for i=1,ww do
        local x=ox+4+(i-1); local y=wy+(wf[id].pts[i] or 0)*7
        if i>1 then screen.line(x,y) else screen.move(x,y) end
      end
      screen.stroke()
    else
      screen.level(2); screen.move(ox+4,wy); screen.line(ox+4+ww,wy); screen.stroke()
    end

    -- position marker
    local run_d=params:get("run_"..pre)
    local mod_pos=(pos+UI.poll_rung*run_d*0.15)%1
    local px=ox+4+mod_pos*ww
    screen.level(is_sel and 15 or 8)
    screen.move(px,wy-8); screen.line(px,wy+8); screen.stroke()
    -- grain window
    local gw=gs*ww*0.3
    screen.level(3); screen.rect(px-gw/2,wy-6,math.max(gw,2),12); screen.stroke()

    -- info
    screen.level(is_sel and 5 or 3); screen.font_size(8)
    screen.move(ox+2,44)
    screen.text("r:"..string.format("%.2f",rate))
    -- xmod
    local xm=id=="A" and params:get("xmod_ba") or params:get("xmod_ab")
    local fm=id=="A" and params:get("xmod_fm_ba") or params:get("xmod_fm_ab")
    if xm>0.01 or fm>0.01 then
      screen.level(4); screen.move(ox+28,44)
      screen.text("x:"..string.format("%.0f",math.max(xm,fm)*100))
    end
  end
  screen.level(15); screen.move(UI.sel_smp=="A" and 26 or 92,50); screen.text("^")
end

-- ── RUNGLER ─────────────────────────────────────────────
function UI.draw_rungler()
  local chaos=params:get("chaos")
  -- CV bar
  local cv_w=math.max(0,math.min(120,math.floor(util.linlin(-1,1,0,120,UI.poll_rung))))
  screen.level(UI.poll_rung>params:get("gate_thresh") and 12 or 5)
  screen.rect(4,12,cv_w,4); screen.fill()
  -- threshold
  local tx=math.floor(util.linlin(-1,1,4,124,params:get("gate_thresh")))
  screen.level(8); screen.move(tx,11); screen.line(tx,17); screen.stroke()

  screen.level(chaos>0.5 and 12 or 5); screen.font_size(8)
  screen.move(4,26); screen.text(chaos>0.5 and "XOR" or "LOOP")
  screen.move(28,26); screen.text("chaos:"..string.format("%.0f%%",chaos*100))
  screen.move(76,26); screen.text("len:"..params:get("loop_len"))

  screen.level(5)
  screen.move(4,36); screen.text("RunA:"..string.format("%.0f%%",params:get("run_a")*100))
  screen.move(48,36); screen.text("RunB:"..string.format("%.0f%%",params:get("run_b")*100))
  screen.move(92,36); screen.text("RunF:"..string.format("%.0f%%",params:get("run_f")*100))

  -- mini CV history
  local s=UI.scope
  if s.len>1 then
    screen.level(6)
    for i=0,math.min(s.len-2,96) do
      local ci=((s.idx-2-i)%UI.scope_size)+1
      local x=124-i; local y=util.clamp(util.linlin(-1,1,50,40,s.x[ci]),40,50)
      if i>0 then screen.line(x,y) else screen.move(x,y) end
    end
    screen.stroke()
  end
end

-- ── FILTER ──────────────────────────────────────────────
function UI.draw_filter()
  local freq=params:get("filt_freq"); local res=params:get("filt_res")
  local ft=params:get("filt_type"); local p2=params:get("filt_peak2")
  local tn={"LP","BP","HP","TP"}; local by,ch=36,20
  local mf=math.max(20,math.min(20000,freq*(1+UI.poll_rung*params:get("run_f")*0.6)))
  screen.level(8); screen.font_size(8)
  screen.move(2,16); screen.text("FILTER "..tn[ft])
  screen.level(5); screen.move(44,16)
  screen.text(mf>=1000 and string.format("%.1fk",mf/1000) or string.format("%.0f",mf))
  screen.move(80,16); screen.text("mix:"..string.format("%.0f%%",params:get("filt_mix")*100))
  screen.level(2); screen.move(4,by); screen.line(124,by); screen.stroke()
  -- primary curve
  screen.level(10)
  for i=0,116 do
    local x=i+4; local fl=util.linlin(0,116,math.log(20),math.log(20000),i)
    local d=math.abs(fl-math.log(mf))
    local r=(ft==2 or ft==4) and math.exp(-(d^2)*4) or (1/(1+(d*2.5)^2))
    r=math.min(r+res*1.5*math.exp(-(d^2)*8),1.5)
    if i>0 then screen.line(x,by-r*ch) else screen.move(x,by-r*ch) end
  end
  screen.stroke()
  -- twin peak
  if ft==4 then
    local f2=math.max(20,math.min(20000,mf*p2))
    screen.level(6)
    for i=0,116 do
      local x=i+4; local fl=util.linlin(0,116,math.log(20),math.log(20000),i)
      local d2=math.abs(fl-math.log(f2))
      local r2=math.exp(-(d2^2)*4)
      r2=math.min(r2+res*1.5*math.exp(-(d2^2)*8),1.5)
      if i>0 then screen.line(x,by-r2*ch) else screen.move(x,by-r2*ch) end
    end
    screen.stroke()
    local f2x=math.floor(util.linlin(math.log(20),math.log(20000),4,120,math.log(f2)))
    screen.level(5); screen.move(f2x,by-ch); screen.line(f2x,by+2); screen.stroke()
  end
  local fx=math.floor(util.linlin(math.log(20),math.log(20000),4,120,math.log(mf)))
  screen.level(15); screen.move(fx,by-ch); screen.line(fx,by+2); screen.stroke()
end

-- ── FX ──────────────────────────────────────────────────
function UI.draw_fx()
  screen.font_size(8)
  screen.level(6); screen.move(4,18); screen.text("CROSS-MOD")
  screen.level(8)
  screen.move(4,26); screen.text("A>B:"..string.format("%.0f%%",params:get("xmod_ab")*100))
  screen.move(40,26); screen.text("B>A:"..string.format("%.0f%%",params:get("xmod_ba")*100))
  screen.move(76,26); screen.text("FM:"..string.format("%.0f%%",(params:get("xmod_fm_ab")+params:get("xmod_fm_ba"))*50))

  screen.level(6); screen.move(4,36); screen.text("DELAY")
  screen.level(8)
  screen.move(4,44); screen.text("t:"..string.format("%.2fs",params:get("dly_time")))
  screen.move(46,44); screen.text("fb:"..string.format("%.0f%%",params:get("dly_fb")*100))
  screen.move(84,44); screen.text("mix:"..string.format("%.0f%%",params:get("dly_mix")*100))
  if params:get("cv_dly")>0.01 then
    screen.level(4); screen.move(4,50)
    screen.text("cv>dly:"..string.format("%.0f%%",params:get("cv_dly")*50))
  end
end

return UI
