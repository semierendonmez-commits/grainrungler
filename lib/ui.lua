-- lib/ui.lua
-- grainrungler: 4 pages, E1 scroll, K1+E1 page

local UI = {}
local R, G, PP, SEL

UI.page = 1; UI.NUM_PAGES = 4
UI.PAGE_NAMES = {"GRAINS","RUNGLER","FILTER","FX"}
UI.sel_smp = "A"; UI.k1_held = false

UI.scope_size = 120
UI.scope = {x={},y={},idx=1,len=0}
for i=1,120 do UI.scope.x[i]=0; UI.scope.y[i]=0 end
function UI.push_scope(x,y)
  UI.scope.x[UI.scope.idx]=x; UI.scope.y[UI.scope.idx]=y
  UI.scope.idx=(UI.scope.idx%UI.scope_size)+1
  if UI.scope.len<UI.scope_size then UI.scope.len=UI.scope.len+1 end
end

local wf_cache = {A={pts={},path=""},B={pts={},path=""}}
local function gen_wf(path, n)
  local pts={}; local h=0
  for i=1,#path do h=(h*31+string.byte(path,i))%99991 end
  math.randomseed(h)
  for i=1,n do pts[i]=(math.random()*2-1)*0.6+math.sin(i/n*math.pi*3+h*0.007)*0.4 end
  math.randomseed(os.time()); return pts
end

function UI.init(r,g,pp,s) R=r; G=g; PP=pp; SEL=s end

function UI.draw()
  screen.clear()
  for i=1,UI.NUM_PAGES do
    screen.level(i==UI.page and 15 or 3)
    screen.rect(2+(i-1)*7,1,4,4)
    if i==UI.page then screen.fill() else screen.stroke() end
  end
  screen.level(10); screen.font_size(8)
  screen.move(34,7); screen.text(UI.PAGE_NAMES[UI.page])
  screen.level(R.gate and 15 or 2); screen.rect(122,2,3,3)
  if R.gate then screen.fill() else screen.stroke() end
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
    local smp=id=="A" and G.A or G.B
    local ox=id=="A" and 0 or 66
    local is_sel=(UI.sel_smp==id)
    screen.level(is_sel and 15 or 5); screen.font_size(8)
    screen.move(ox+2,17); screen.text(id)
    screen.level(smp.loaded and 7 or 2); screen.move(ox+10,17)
    screen.text(smp.loaded and string.format("%.1fs",smp.length) or "---")

    local wy,ww=30,50
    if smp.loaded then
      local c=wf_cache[id]
      if c.path~=smp.path then c.pts=gen_wf(smp.path,ww); c.path=smp.path end
      screen.level(is_sel and 7 or 4)
      for i=1,ww do
        local x=ox+4+(i-1); local y=wy+(c.pts[i] or 0)*7
        if i>1 then screen.line(x,y) else screen.move(x,y) end
      end
      screen.stroke()
    else
      screen.level(2); screen.move(ox+4,wy); screen.line(ox+4+ww,wy); screen.stroke()
    end

    local run_d=id=="A" and R.run_a or R.run_b
    local pos=(smp.position+R.cv*run_d*0.15)%1
    local px=ox+4+pos*ww
    screen.level(is_sel and 15 or 8)
    screen.move(px,wy-8); screen.line(px,wy+8); screen.stroke()
    local gw=smp.grain_size*ww*0.5
    screen.level(3); screen.rect(px-gw/2,wy-6,math.max(gw,2),12); screen.stroke()

    screen.level(is_sel and 5 or 3); screen.font_size(8)
    screen.move(ox+2,44); screen.text("r:"..string.format("%.2f",smp.rate))
    if smp.pulse==1 then screen.level(15); screen.rect(ox+50,12,4,4); screen.fill() end

    -- xmod indicator
    local xm=id=="A" and G.xmod_b_to_a or G.xmod_a_to_b
    if xm>0.01 then
      screen.level(4); screen.move(ox+28,44)
      screen.text("x:"..string.format("%.0f%%",xm*100))
    end
  end
  screen.level(15); screen.move(UI.sel_smp=="A" and 26 or 92,50); screen.text("^")
  if G.recording then screen.level(15); screen.move(64,50); screen.text_center("REC") end
end

-- ── RUNGLER ─────────────────────────────────────────────
function UI.draw_rungler()
  local bw,gap=12,2; local sx=math.floor((128-8*(bw+gap))/2); local ry=11
  for i=1,8 do
    local x=sx+(i-1)*(bw+gap)
    screen.level(i<=R.loop_len and (R.reg[i]==1 and 15 or 6) or 2)
    screen.rect(x,ry,bw,8)
    if i<=R.loop_len and R.reg[i]==1 then screen.fill() else screen.stroke() end
  end
  screen.level(math.floor(4+R.chaos*8))
  local lx=sx+7*(bw+gap)+bw
  screen.move(lx,ry+8); screen.line(lx,ry+12)
  screen.line(sx,ry+12); screen.line(sx,ry+8); screen.stroke()
  screen.level(R.chaos>0.5 and 12 or 5); screen.font_size(8)
  screen.move(64-6,ry+18); screen.text(R.chaos>0.5 and "XOR" or "LOOP")
  local cv_w=math.max(0,math.min(120,math.floor(util.linlin(-1,1,0,120,R.cv))))
  screen.level(R.gate and 12 or 5); screen.rect(4,34,cv_w,3); screen.fill()
  screen.level(5); screen.font_size(8)
  screen.move(4,46); screen.text("A:"..string.format("%.0f%%",R.run_a*100))
  screen.move(30,46); screen.text("B:"..string.format("%.0f%%",R.run_b*100))
  screen.move(56,46); screen.text("F:"..string.format("%.0f%%",R.run_f*100))
  -- mini scope
  local s=UI.scope
  if s.len>1 then
    screen.level(2); screen.rect(80,38,42,12); screen.stroke()
    for i=0,math.min(s.len-2,38) do
      local ci=((s.idx-2-i)%UI.scope_size)+1
      screen.level(math.max(1,math.floor(6*(1-i/39))))
      screen.pixel(80+41-i,util.clamp(util.linlin(-1,1,50,38,s.x[ci]),38,50)); screen.fill()
    end
  end
end

-- ── FILTER ──────────────────────────────────────────────
function UI.draw_filter()
  local freq=G.filter_freq; local res=G.filter_res; local ft=G.filter_type
  local tn={"LP","BP","HP"}; local by,ch=36,18
  local mf=math.max(40,math.min(18000,freq*(1+R.cv*R.run_f*0.6)))
  screen.level(8); screen.font_size(8)
  screen.move(2,16); screen.text("FILTER "..tn[ft])
  screen.level(5); screen.move(44,16)
  screen.text(mf>=1000 and string.format("%.1fk",mf/1000) or string.format("%.0f",mf))
  screen.move(80,16); screen.text("mix:"..string.format("%.0f%%",G.filter_mix*100))
  screen.level(2); screen.move(4,by); screen.line(124,by); screen.stroke()
  screen.level(10)
  for i=0,116 do
    local x=i+4; local fl=util.linlin(0,116,math.log(40),math.log(18000),i)
    local d=math.abs(fl-math.log(mf))
    local r=(ft==2) and math.exp(-(d^2)*4) or (1/(1+(d*2.5)^2))
    r=math.min(r+(1/res)*0.5*math.exp(-(d^2)*8),1.5)
    if i>0 then screen.line(x,by-r*ch) else screen.move(x,by-r*ch) end
  end
  screen.stroke()
  local fx=math.floor(util.linlin(math.log(40),math.log(18000),4,120,math.log(mf)))
  screen.level(15); screen.move(fx,by-ch); screen.line(fx,by+2); screen.stroke()
end

-- ── FX ──────────────────────────────────────────────────
function UI.draw_fx()
  screen.font_size(8)
  -- cross-mod
  screen.level(6); screen.move(4,18); screen.text("CROSS-MOD")
  screen.level(8); screen.move(4,26)
  screen.text("A>B: "..string.format("%.0f%%",G.xmod_a_to_b*100))
  screen.move(50,26)
  screen.text("B>A: "..string.format("%.0f%%",G.xmod_b_to_a*100))
  -- delay
  screen.level(6); screen.move(4,36); screen.text("DELAY")
  screen.level(8); screen.move(4,44)
  screen.text("t:"..string.format("%.2fs",G.delay_time))
  screen.move(50,44); screen.text("fb:"..string.format("%.0f%%",G.delay_fb*100))
  screen.move(90,44); screen.text("snd:"..string.format("%.0f%%",G.delay_send*100))
  if G.cv_to_delay>0.01 then
    screen.level(4); screen.move(4,50)
    screen.text("cv>dly:"..string.format("%.0f%%",G.cv_to_delay*50))
  end
end

return UI
