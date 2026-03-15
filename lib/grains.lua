-- lib/grains.lua
-- dual-sample granular + softcut delay
-- NO SC engine — pure softcut
--
-- voices 1-2: sample A (stereo pair)
-- voices 3-4: sample B (stereo pair)
-- voice 5: delay writer (records grain output)
-- voice 6: delay reader (plays back with offset)

local G = {}
local R

-- ── delay config ────────────────────────────────────────
local DLY_BUF = 2        -- use buffer 2 for delay region
local DLY_START = 300     -- start position in buffer (safe from sample B)
local DLY_LEN = 8         -- max delay seconds

-- ── per-sample ──────────────────────────────────────────
local function new_smp(buf, voices)
  return {
    buffer=buf, voices=voices, path="", length=0, loaded=false,
    position=0, rate=1.0, grain_size=0.12, level=0.8,
    -- envelope
    attack=0.01, release=0.05,
    -- phase → pulse for rungler
    phase=0, prev_phase=0, pulse=0,
    -- amplitude tracker for cross-mod
    amp_env=0,
  }
end

G.A = new_smp(1, {1, 2})
G.B = new_smp(2, {3, 4})
G.B.rate = 0.25

-- ── cross-mod depths ────────────────────────────────────
G.xmod_a_to_b = 0  -- A amplitude → B rate/position
G.xmod_b_to_a = 0  -- B amplitude → A rate/position

-- ── filter ──────────────────────────────────────────────
G.filter_freq = 4000
G.filter_res = 2.0   -- rq: lower = more resonant
G.filter_type = 1    -- 1=LP, 2=BP, 3=HP
G.filter_mix = 1.0   -- 0=dry, 1=filtered

-- ── delay ───────────────────────────────────────────────
G.delay_time = 0
G.delay_fb = 0
G.delay_send = 0.3
G.cv_to_delay = 0   -- rungler mod on delay

-- ── stereo ──────────────────────────────────────────────
G.spread = 0.5

-- ── recording ───────────────────────────────────────────
G.rec_target = "A"
G.recording = false
G.rec_start = 0

-- ── init ─────────────────────────────────────────────────
function G.init(rungler)
  R = rungler

  -- grain voices
  for _, v in ipairs({1,2,3,4}) do
    local buf = (v <= 2) and 1 or 2
    softcut.enable(v, 1)
    softcut.buffer(v, buf)
    softcut.level(v, 0.8)
    softcut.loop(v, 1)
    softcut.rate(v, 1)
    softcut.play(v, 0)
    softcut.position(v, 0)
    softcut.fade_time(v, 0.01)
    softcut.level_slew_time(v, 0.02)
    softcut.rate_slew_time(v, 0.05)
    -- filter defaults
    softcut.pre_filter_dry(v, 0)
    softcut.pre_filter_lp(v, 1)
    softcut.pre_filter_bp(v, 0)
    softcut.pre_filter_hp(v, 0)
    softcut.pre_filter_fc(v, 4000)
    softcut.pre_filter_rq(v, 2)
    -- panning
    local pan = 0
    if v == 1 then pan = -0.4
    elseif v == 2 then pan = 0.15
    elseif v == 3 then pan = -0.15
    elseif v == 4 then pan = 0.4 end
    softcut.pan(v, pan)
  end

  -- delay writer (voice 5)
  softcut.enable(5, 1)
  softcut.buffer(5, DLY_BUF)
  softcut.loop(5, 1)
  softcut.loop_start(5, DLY_START)
  softcut.loop_end(5, DLY_START + DLY_LEN)
  softcut.rate(5, 1)
  softcut.position(5, DLY_START)
  softcut.play(5, 1)
  softcut.rec(5, 1)
  softcut.rec_level(5, 1.0)
  softcut.pre_level(5, 0)   -- feedback
  softcut.level(5, 0)       -- writer is silent
  softcut.fade_time(5, 0.01)
  -- route grain voices → delay writer
  for v = 1, 4 do softcut.level_cut_cut(v, 5, 0) end

  -- delay reader (voice 6)
  softcut.enable(6, 1)
  softcut.buffer(6, DLY_BUF)
  softcut.loop(6, 1)
  softcut.loop_start(6, DLY_START)
  softcut.loop_end(6, DLY_START + DLY_LEN)
  softcut.rate(6, 1)
  softcut.position(6, DLY_START)
  softcut.play(6, 1)
  softcut.rec(6, 0)
  softcut.level(6, 0)       -- delay output level
  softcut.pan(6, 0)
  softcut.fade_time(6, 0.05)

  -- route delay reader → delay writer for feedback
  softcut.level_cut_cut(6, 5, 0)

  -- track delay writer position
  softcut.phase_quant(5, 0.05)
  softcut.event_phase(function(voice, pos)
    if voice == 5 then
      G._dly_write_pos = pos
    end
  end)
  G._dly_write_pos = DLY_START
end

-- ── load sample ─────────────────────────────────────────
function G.load_sample(target, path)
  if not path or path == "" then return end
  local smp = target == "A" and G.A or G.B
  softcut.buffer_clear_channel(smp.buffer)
  softcut.buffer_read_mono(path, 0, 0, -1, 1, smp.buffer)
  local ch, samples, sr = audio.file_info(path)
  smp.length = (samples and sr and sr > 0) and (samples / sr) or 10
  smp.path = path; smp.loaded = true
  for _, v in ipairs(smp.voices) do
    softcut.loop_start(v, 0); softcut.loop_end(v, smp.length)
    softcut.play(v, 1)
  end
end

-- ── recording ───────────────────────────────────────────
function G.start_rec(target)
  -- temporarily use voice 5 for recording (pause delay)
  G.rec_target = target
  local buf = target == "A" and 1 or 2
  softcut.rec(5, 0); softcut.play(5, 0)
  softcut.buffer(5, buf)
  softcut.loop_start(5, 0); softcut.loop_end(5, softcut.BUFFER_SIZE)
  softcut.position(5, 0)
  softcut.rec_level(5, 1); softcut.pre_level(5, 0)
  softcut.level_input_cut(1, 5, 1); softcut.level_input_cut(2, 5, 1)
  softcut.rec(5, 1); softcut.play(5, 1)
  G.recording = true; G.rec_start = util.time()
end

function G.stop_rec()
  softcut.rec(5, 0); softcut.play(5, 0)
  softcut.level_input_cut(1, 5, 0); softcut.level_input_cut(2, 5, 0)
  G.recording = false
  local smp = G.rec_target == "A" and G.A or G.B
  smp.length = util.time() - G.rec_start
  smp.loaded = true; smp.path = "[rec:" .. G.rec_target .. "]"
  for _, v in ipairs(smp.voices) do
    softcut.loop_start(v, 0); softcut.loop_end(v, smp.length); softcut.play(v, 1)
  end
  -- restore delay writer
  G.init_delay()
end

function G.init_delay()
  softcut.buffer(5, DLY_BUF)
  softcut.loop_start(5, DLY_START); softcut.loop_end(5, DLY_START + DLY_LEN)
  softcut.rate(5, 1); softcut.position(5, DLY_START)
  softcut.rec_level(5, 1); softcut.level_input_cut(1, 5, 0); softcut.level_input_cut(2, 5, 0)
  softcut.rec(5, 1); softcut.play(5, 1)
  softcut.level(5, 0)
  G.update_delay()
end

-- ── delay params update ─────────────────────────────────
function G.update_delay()
  local send = G.delay_send
  local fb = G.delay_fb
  local dly_t = math.max(0.01, G.delay_time + R.cv * G.cv_to_delay * G.delay_time * 0.5)
  dly_t = math.min(dly_t, DLY_LEN - 0.1)

  -- send levels from grains to delay
  for v = 1, 4 do softcut.level_cut_cut(v, 5, G.delay_time > 0.01 and send or 0) end
  -- feedback
  softcut.pre_level(5, fb)
  softcut.level_cut_cut(6, 5, fb * 0.5)
  -- reader output
  softcut.level(6, G.delay_time > 0.01 and 0.5 or 0)
end

-- ── update sample ───────────────────────────────────────
local function update_smp(smp, run_depth, other_amp, xmod_depth, dt)
  if not smp.loaded then return end

  -- rungler CV modulates rate
  local cv = R.cv
  local mod_rate = smp.rate * (1 + cv * run_depth)
  -- cross-mod: other sample's amplitude modulates this one's rate
  mod_rate = mod_rate + other_amp * xmod_depth * smp.rate * 0.5
  mod_rate = math.max(-4, math.min(4, mod_rate))
  if math.abs(mod_rate) < 0.005 then mod_rate = 0.005 end

  local mod_pos = (smp.position + cv * run_depth * 0.15 + other_amp * xmod_depth * 0.1) % 1

  -- grain envelope via level
  local gs = math.max(0.02, math.min(2.0, smp.grain_size))

  -- phase tracking → pulse
  smp.prev_phase = smp.phase
  smp.phase = (smp.phase + math.abs(mod_rate) * dt / gs) % 1
  smp.pulse = (smp.phase < smp.prev_phase) and 1 or 0

  -- amplitude tracking (smooth envelope follower)
  smp.amp_env = smp.amp_env * 0.92 + math.abs(cv * run_depth) * 0.08

  -- filter
  local f_freq = math.max(40, math.min(18000,
    G.filter_freq * (1 + cv * R.run_f * 0.6)))
  local lp = G.filter_type == 1 and G.filter_mix or 0
  local bp = G.filter_type == 2 and G.filter_mix or 0
  local hp = G.filter_type == 3 and G.filter_mix or 0
  local dry = 1 - G.filter_mix

  for i, v in ipairs(smp.voices) do
    local v_spread = (i - 1) * G.spread * 0.2
    local v_pos = (mod_pos + v_spread) % 1

    softcut.rate(v, mod_rate)

    -- grain window: set loop region around position
    local center = v_pos * smp.length
    local half = gs * 0.5 * math.abs(smp.rate)  -- scale with base rate
    half = math.max(0.01, math.min(smp.length * 0.4, half))
    local ls = math.max(0, center - half)
    local le = math.min(smp.length, center + half)
    if le - ls < 0.02 then le = ls + 0.02 end
    softcut.loop_start(v, ls)
    softcut.loop_end(v, le)

    -- level with envelope shape
    local env_phase = smp.phase
    local env = 1.0
    if env_phase < smp.attack then
      env = env_phase / math.max(smp.attack, 0.001)
    elseif env_phase > (1 - smp.release) then
      env = (1 - env_phase) / math.max(smp.release, 0.001)
    end
    env = math.max(0, math.min(1, env))
    softcut.level(v, smp.level * env)

    -- filter
    softcut.pre_filter_dry(v, dry)
    softcut.pre_filter_lp(v, lp)
    softcut.pre_filter_bp(v, bp)
    softcut.pre_filter_hp(v, hp)
    softcut.pre_filter_fc(v, f_freq)
    softcut.pre_filter_rq(v, G.filter_res)
  end
end

-- ── main update ─────────────────────────────────────────
function G.update(dt)
  update_smp(G.A, R.run_a, G.B.amp_env, G.xmod_b_to_a, dt)
  update_smp(G.B, R.run_b, G.A.amp_env, G.xmod_a_to_b, dt)
  -- delay position tracking
  if not G.recording and G.delay_time > 0.01 then
    G.update_delay()
    -- keep reader behind writer
    local read_pos = G._dly_write_pos - G.delay_time
    if read_pos < DLY_START then read_pos = read_pos + DLY_LEN end
    softcut.position(6, read_pos)
  end
end

function G.get_data_pulse() return G.A.pulse end
function G.get_clock_pulse() return G.B.pulse end

function G.cleanup()
  for v = 1, 6 do softcut.play(v, 0); softcut.rec(v, 0) end
end

return G
