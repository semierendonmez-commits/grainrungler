-- lib/ui.lua
-- grainrungler v2: 5 pages

local UI = {}
local PP, SEL

UI.page=1; UI.NUM_PAGES=5
UI.PAGE_NAMES={"GRAINS","RUNGLER","XMOD","FILTER","FX"}
UI.sel_smp="A"; UI.k1_held=false
UI.poll_rung=0; UI.poll_amp=0

UI.scope_size=100; UI.scope={x={},idx=1,len=0}
for i=1,100 do UI.scope.x[i]=0 end
function UI.push_scope(x)
  UI.scope.x[UI.scope.idx]=x
  UI.scope.idx=(UI.scope.idx%UI.scope_size)+1
  if UI.scope.len<UI.scope_size then UI.scope.len=UI.scope.len+1 end
end

local wfc={A={pts={},p=""},B={pts={},p=""}}
local function gwf(path,n)
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
    screen.rect(2+(i-1)*6,1,3,3)
    if i==UI.page then screen.fill() else screen.stroke() end
  end
  screen.level(10); screen.font_size(8)
  screen.move(36,7); screen.text(UI.PAGE_NAMES[UI.page])
  local aw=math.floor(UI.poll_amp*16)
  if aw>0 then
    screen.level(math.floor(3+UI.poll_amp*10))
    screen.rect(104,2,aw,3); screen.fill()
  end
  screen.level(1); screen.move(0,9); screen.line(128,9); screen.stroke()
  local fn={UI.draw_grains,UI.draw_rungler,UI.draw_xmod,UI.draw_filter,UI.draw_fx}
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
    local ox=id=="A" and 0 or 66; local pre=string.lower(id)
    local is_sel=(UI.sel_smp==id)
    local path_val=params:get("sample_"..pre)
    local loaded=(path_val and path_val~="" and path_val~=_path.audio)

    screen.level(is_sel and 15 or 5); screen.font_size(8)
    screen.move(ox+2,17); screen.text(id)
    screen.level(loaded and 7 or 2); screen.move(ox+10,17)
    if loaded then screen.text(string.sub(path_val:match("[^/]+$") or "?",1,7))
    else screen.text("---") end

    local wy,ww=30,50
    if loaded then
      if wfc[id].p~=path_val then wfc[id].pts=gwf(path_val,ww); wfc[id].p=path_val end
      screen.level(is_sel and 7 or 4)
      for i=1,ww do
        local x=ox+4+(i-1); local y=wy+(wfc[id].pts[i] or 0)*7
        if i>1 then screen.line(x,y) else screen.move(x,y) end
      end
      screen.stroke()
    else
      screen.level(2); screen.move(ox+4,wy); screen.line(ox+4+ww,wy); screen.stroke()
    end

    local run_d=params:get("run_"..pre)
    local pos=(params:get("pos_"..pre)+UI.poll_rung*run_d*0.15)%1
    local px=ox+4+pos*ww
    screen.level(is_sel and 15 or 8)
    screen.move(px,wy-8); screen.line(px,wy+8); screen.stroke()
    local gw=params:get("grain_"..pre)*ww*0.3
    screen.level(3); screen.rect(px-gw/2,wy-6,math.max(gw,2),12); screen.stroke()

    screen.level(is_sel and 5 or 3); screen.font_size(8)
    screen.move(ox+2,44); screen.text("r:"..string.format("%.2f",params:get("rate_"..pre)))
  end
  screen.level(15); screen.move(UI.sel_smp=="A" and 26 or 92,50); screen.text("^")
end

-- ── RUNGLER ─────────────────────────────────────────────
function UI.draw_rungler()
  local chaos=params:get("chaos")
  local cv_w=math.max(0,math.min(120,math.floor(util.linlin(-1,1,0,120,UI.poll_rung))))
  screen.level(UI.poll_rung>params:get("gate_thresh") and 12 or 5)
  screen.rect(4,12,cv_w,4); screen.fill()
  local tx=math.floor(util.linlin(-1,1,4,124,params:get("gate_thresh")))
  screen.level(8); screen.move(tx,11); screen.line(tx,17); screen.stroke()

  screen.level(chaos>0.5 and 12 or 5); screen.font_size(8)
  screen.move(4,26); screen.text(chaos>0.5 and "XOR" or "LOOP")
  screen.move(28,26); screen.text("chaos:"..string.format("%.0f%%",chaos*100))
  screen.move(76,26); screen.text("len:"..params:get("loop_len"))

  screen.level(5)
  screen.move(4,36); screen.text("A:"..string.format("%.0f%%",params:get("run_a")*100))
  screen.move(36,36); screen.text("B:"..string.format("%.0f%%",params:get("run_b")*100))
  screen.move(68,36); screen.text("F:"..string.format("%.0f%%",params:get("run_f")*100))

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

-- ── CROSS-MOD ───────────────────────────────────────────
function UI.draw_xmod()
  screen.font_size(8)
  -- phase mod viz
  screen.level(8); screen.move(4,18); screen.text("PHASE MOD (spectral)")
  local pm_ab=params:get("xmod_pm_ab"); local pm_ba=params:get("xmod_pm_ba")
  screen.level(12)
  screen.move(4,28); screen.text("A>B: "..string.format("%.0f%%",pm_ab*100))
  screen.move(50,28); screen.text("B>A: "..string.format("%.0f%%",pm_ba*100))

  -- visual: two interlocking circles
  local cx=64; local cy=22; local r=6
  screen.level(math.floor(3+pm_ab*10))
  screen.circle(cx-8,cy,r); screen.stroke()
  screen.level(math.floor(3+pm_ba*10))
  screen.circle(cx+8,cy,r); screen.stroke()
  -- overlap indicator
  if pm_ab>0.01 or pm_ba>0.01 then
    screen.level(math.floor(4+(pm_ab+pm_ba)*5))
    screen.circle(cx,cy,3); screen.fill()
  end

  screen.level(6); screen.move(4,38); screen.text("AMP MOD (dynamics)")
  local amp_ab=params:get("xmod_amp_ab"); local amp_ba=params:get("xmod_amp_ba")
  screen.level(10)
  screen.move(4,46); screen.text("A>B: "..string.format("%.0f%%",amp_ab*100))
  screen.move(50,46); screen.text("B>A: "..string.format("%.0f%%",amp_ba*100))
end

-- ── FILTER ──────────────────────────────────────────────
function UI.draw_filter()
  local freq=params:get("filt_freq"); local res=params:get("filt_res")
  local ft=params:get("filt_type"); local p2=params:get("filt_peak2")
  local tn={"LP","BP","HP","TP"}; local by,ch=34,16
  local mf=math.max(20,math.min(20000,freq*(1+UI.poll_rung*params:get("run_f")*0.6)))
  screen.level(8); screen.font_size(8)
  screen.move(2,16); screen.text("FILT "..tn[ft])
  screen.level(5); screen.move(30,16)
  screen.text(mf>=1000 and string.format("%.1fk",mf/1000) or string.format("%.0f",mf))
  screen.move(60,16); screen.text("mix:"..string.format("%.0f%%",params:get("filt_mix")*100))
  screen.level(2); screen.move(4,by); screen.line(124,by); screen.stroke()
  screen.level(10)
  for i=0,116 do
    local x=i+4; local fl=util.linlin(0,116,math.log(20),math.log(20000),i)
    local d=math.abs(fl-math.log(mf))
    local r=(ft==2 or ft==4) and math.exp(-(d^2)*4) or (1/(1+(d*2.5)^2))
    r=math.min(r+res*1.5*math.exp(-(d^2)*8),1.5)
    if i>0 then screen.line(x,by-r*ch) else screen.move(x,by-r*ch) end
  end
  screen.stroke()
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
  end
  local fx=math.floor(util.linlin(math.log(20),math.log(20000),4,120,math.log(mf)))
  screen.level(15); screen.move(fx,by-ch); screen.line(fx,by+2); screen.stroke()

  -- comb info
  local cmix=params:get("comb_mix")
  if cmix>0.01 then
    screen.level(5); screen.move(4,42)
    screen.text("COMB "..string.format("%.0fHz",params:get("comb_freq"))
      .." fb:"..string.format("%.0f%%",params:get("comb_fb")*100)
      .." mix:"..string.format("%.0f%%",cmix*100))
  end
end

-- ── FX ──────────────────────────────────────────────────
function UI.draw_fx()
  screen.font_size(8)
  screen.level(6); screen.move(4,18); screen.text("DELAY")
  screen.level(8)
  screen.move(4,26); screen.text("t:"..string.format("%.2fs",params:get("dly_time")))
  screen.move(40,26); screen.text("fb:"..string.format("%.0f%%",params:get("dly_fb")*100))
  screen.move(76,26); screen.text("mix:"..string.format("%.0f%%",params:get("dly_mix")*100))
  if params:get("cv_dly")>0.01 then
    screen.level(4); screen.move(4,34)
    screen.text("cv>dly:"..string.format("%.0f%%",params:get("cv_dly")*50))
  end

  screen.level(6); screen.move(4,42); screen.text("PAN")
  local pm=params:get("pan_mode"); local pn={"static","rungler","random"}
  screen.level(8); screen.move(22,42); screen.text(pn[pm])
  screen.move(60,42); screen.text("width:"..string.format("%.0f%%",params:get("pan_width")*100))
end

return UI
