-- lib/rungler.lua
-- benjolin rungler: 8-bit shift register
-- sample A wrapping → DATA, sample B wrapping → CLOCK

local R = {}

R.reg = {0,0,0,0,0,0,0,0}
R.loop_len = 8
R.chaos = 1.0
R.cv = 0
R.gate = false
R.gate_thresh = 0.3

R.run_a = 0
R.run_b = 0
R.run_f = 0

R.freq_a = 4; R.freq_b = 0.5
R.phase_a = 0; R.phase_b = 0
R.source_mix = 0
R.tri_a = 0; R.tri_b = 0
R.prev_clock = 0

function R.clock_tick(ext_data, ext_clock, dt)
  -- internal oscillators (modulated by CV feedback)
  local fa = R.freq_a * (1 + R.cv * R.run_a * 0.3)
  local fb = R.freq_b * (1 + R.cv * R.run_b * 0.3)
  fa = math.max(0.01, math.min(200, fa))
  fb = math.max(0.01, math.min(200, fb))
  R.phase_a = (R.phase_a + fa * dt) % 1
  R.phase_b = (R.phase_b + fb * dt) % 1
  R.tri_a = R.phase_a < 0.5 and (R.phase_a*4-1) or (3-R.phase_a*4)
  R.tri_b = R.phase_b < 0.5 and (R.phase_b*4-1) or (3-R.phase_b*4)

  local int_data = R.phase_a < 0.5 and 1 or 0
  local int_clock = R.phase_b < 0.5 and 1 or 0

  -- source selection
  local data_bit, clock_bit
  local mix = R.source_mix
  if mix <= 0.01 then
    data_bit = ext_data; clock_bit = ext_clock
  elseif mix >= 0.99 then
    data_bit = int_data; clock_bit = int_clock
  else
    data_bit = (ext_data == 1 or (int_data == 1 and mix > 0.5)) and 1 or 0
    clock_bit = (ext_clock == 1 or (int_clock == 1 and mix > 0.5)) and 1 or 0
  end

  local edge = (clock_bit == 1 and R.prev_clock == 0)
  R.prev_clock = clock_bit

  if edge then
    local last = R.reg[8]
    local xor = (data_bit ~= last) and 1 or 0
    local new = R.chaos > 0.5 and xor or data_bit
    for i = 8, 2, -1 do R.reg[i] = R.reg[i-1] end
    R.reg[1] = new
    local ll = math.max(3, math.min(8, R.loop_len))
    local b1 = R.reg[math.max(1,ll-2)] or 0
    local b2 = R.reg[math.max(1,ll-1)] or 0
    local b3 = R.reg[math.max(1,ll)] or 0
    R.cv = ((b1*0.25 + b2*0.5 + b3*1.0) / 1.75) * 2 - 1
  end
  R.gate = R.cv > R.gate_thresh
end

return R
