// lib/Engine_GrainRungler.sc
// v2: TRUE phase modulation between samples
// sample A output → modulates sample B read position (and vice versa)
// this creates real spectral changes, sidebands, fusion
// + comb filter, stereo buffers, pan modes, stereo delay

Engine_GrainRungler : CroneEngine {
  var <synth;
  var <bufA, <bufB;
  var rungBus, ampBus;

  *new { |context, doneCallback| ^super.new(context, doneCallback) }

  alloc {
    bufA = Buffer.alloc(context.server, 48000 * 60, 2); // stereo
    bufB = Buffer.alloc(context.server, 48000 * 60, 2);

    rungBus = Bus.control(context.server, 1);
    ampBus  = Bus.control(context.server, 1);

    SynthDef(\grainrungler, {
      arg buf_a=0, buf_b=0,
          // sample A grain params
          pos_a=0, rate_a=1, grain_a=0.12, level_a=0.8,
          atk_a=0.01, rel_a=0.05, len_a=1,
          jitter_a=0,   // random position scatter (0-500ms)
          density_a=20, // grain trigger rate (Hz)
          // sample B grain params
          pos_b=0, rate_b=0.25, grain_b=0.2, level_b=0.8,
          atk_b=0.01, rel_b=0.05, len_b=1,
          jitter_b=0,
          density_b=20,
          // rungler
          run_a=0.5, run_b=0.3, run_f=0.4,
          chaos=1, loop_len=8, gate_thresh=0.3,
          // cross-mod: REAL audio-rate phase modulation
          xmod_pm_ab=0, // A output → B read position (phase mod)
          xmod_pm_ba=0, // B output → A read position
          xmod_amp_ab=0, // A amplitude → B level
          xmod_amp_ba=0, // B amplitude → A level
          // filter
          filt_freq=2000, filt_res=0.5, filt_type=0,
          filt_peak2=1.5, filt_mix=0.8,
          // comb filter
          comb_freq=200, comb_fb=0, comb_mix=0,
          // delay (stereo)
          dly_time=0, dly_fb=0, dly_mix=0, cv_dly=0,
          // master
          spread=0.5, amp=0.8,
          pan_mode=0, pan_width=0.5, // 0=static,1=rungler,2=random
          // buses
          rung_bus=0, amp_bus=0;

      // ── all vars ─────────────────────────────────────
      var phasor_a, phasor_b, read_a, read_b;
      var sig_a_raw, sig_b_raw, sig_a, sig_b;
      var env_a, env_b;
      var amp_env_a, amp_env_b;
      var pos_samp_a, pos_samp_b;
      var grain_samp_a, grain_samp_b;
      var start_a, end_a, start_b, end_b;
      var rate_mod_a, rate_mod_b;
      var jitter_sig_a, jitter_sig_b;
      var density_trig_a, density_trig_b;
      var sh0, sh1, sh2, sh3, sh4, sh5, sh6, sh7;
      var data_bit, clock_sig, xor_bit, rungler_cv, rung, trig;
      var fb_rung, prev_rung, prev_last;
      var filt_in, f_freq, filt_out;
      var f_lp, f_bp, f_hp, f_tp;
      var comb_sig;
      var mix_l, mix_r;
      var dly_t, dly_l, dly_r;
      var out_l, out_r;
      var pan_sig;

      // ── rungler feedback (3ch: rung, last_bit, sample_mix) ──
      fb_rung   = LocalIn.ar(3, 0);
      prev_rung = fb_rung[0];
      prev_last = fb_rung[1];

      // ── rate modulation (rungler → rate) ─────────────
      rate_mod_a = rate_a * (1 + (prev_rung * run_a));
      rate_mod_a = rate_mod_a.clip(-4, 4);
      rate_mod_b = rate_b * (1 + (prev_rung * run_b));
      rate_mod_b = rate_mod_b.clip(-4, 4);

      // ── amplitude followers for position cross-mod ───
      // fb_rung[2] carries mixed sample output from previous frame
      amp_env_a = Amplitude.ar(fb_rung[2], 0.003, 0.02);
      amp_env_b = Amplitude.ar(fb_rung[2], 0.003, 0.02);

      // ── grain regions (with cross-mod position) ──────
      // jitter: random scatter (rungler-modulated)
      jitter_sig_a = LFNoise1.ar(density_a.max(1))
        * (jitter_a + (prev_rung.abs * run_a * jitter_a * 0.5))
        * SampleRate.ir * 0.001; // ms to samples
      jitter_sig_b = LFNoise1.ar(density_b.max(1))
        * (jitter_b + (prev_rung.abs * run_b * jitter_b * 0.5))
        * SampleRate.ir * 0.001;

      // density triggers (for grain envelope)
      density_trig_a = Impulse.ar(density_a + (prev_rung.abs * run_a * density_a * 0.3));
      density_trig_b = Impulse.ar(density_b + (prev_rung.abs * run_b * density_b * 0.3));

      // rungler + other sample's amplitude shift position
      pos_samp_a = (pos_a
        + (prev_rung * run_a * 0.2)
        + (amp_env_b * xmod_amp_ba * 0.3)
      ).wrap(0, 1) * len_a * SampleRate.ir;

      pos_samp_b = (pos_b
        + (prev_rung * run_b * 0.2)
        + (amp_env_a * xmod_amp_ab * 0.3)
      ).wrap(0, 1) * len_b * SampleRate.ir;

      grain_samp_a = (grain_a * rate_mod_a.abs.max(0.01) * SampleRate.ir)
        .clip(480, len_a * SampleRate.ir * 0.5);
      grain_samp_b = (grain_b * rate_mod_b.abs.max(0.01) * SampleRate.ir)
        .clip(480, len_b * SampleRate.ir * 0.5);

      start_a = (pos_samp_a - (grain_samp_a * 0.5)).max(0);
      end_a   = (pos_samp_a + (grain_samp_a * 0.5)).min(BufFrames.kr(buf_a) - 1);
      start_b = (pos_samp_b - (grain_samp_b * 0.5)).max(0);
      end_b   = (pos_samp_b + (grain_samp_b * 0.5)).min(BufFrames.kr(buf_b) - 1);

      // ── base phasors (with jitter) ─────────────────────
      phasor_a = Phasor.ar(0, rate_mod_a * BufRateScale.kr(buf_a), start_a, end_a);
      phasor_b = Phasor.ar(0, rate_mod_b * BufRateScale.kr(buf_b), start_b, end_b);

      // ── FIRST PASS: read raw samples (with jitter) ────
      sig_a_raw = BufRd.ar(2, buf_a, (phasor_a + jitter_sig_a).clip(0, BufFrames.kr(buf_a)-1), 1, 4);
      sig_b_raw = BufRd.ar(2, buf_b, (phasor_b + jitter_sig_b).clip(0, BufFrames.kr(buf_b)-1), 1, 4);

      // ── TRUE PHASE MODULATION ────────────────────────
      read_a = (phasor_a + jitter_sig_a
        + (sig_b_raw[0] * xmod_pm_ba * grain_samp_a * 0.5)
        + (sig_b_raw[1] * xmod_pm_ba * grain_samp_a * 0.15)
      ).clip(0, BufFrames.kr(buf_a) - 1);

      read_b = (phasor_b + jitter_sig_b
        + (sig_a_raw[0] * xmod_pm_ab * grain_samp_b * 0.5)
        + (sig_a_raw[1] * xmod_pm_ab * grain_samp_b * 0.15)
      ).clip(0, BufFrames.kr(buf_b) - 1);

      // ── SECOND PASS: read with jitter + phase mod ─────
      sig_a_raw = BufRd.ar(2, buf_a, read_a, 1, 4);
      sig_b_raw = BufRd.ar(2, buf_b, read_b, 1, 4);

      // ── grain envelope (density-triggered) ─────────────
      // density controls how often grains retrigger
      // higher density = more overlapping grains = denser texture
      env_a = EnvGen.ar(Env.linen(atk_a, grain_a, rel_a, 1, \sin), density_trig_a);
      env_b = EnvGen.ar(Env.linen(atk_b, grain_b, rel_b, 1, \sin), density_trig_b);

      // ── amplitude cross-mod ──────────────────────────
      amp_env_a = Amplitude.ar(sig_a_raw[0], 0.005, 0.03);
      amp_env_b = Amplitude.ar(sig_b_raw[0], 0.005, 0.03);

      sig_a = sig_a_raw * env_a * level_a * (1 + (amp_env_b * xmod_amp_ba));
      sig_b = sig_b_raw * env_b * level_b * (1 + (amp_env_a * xmod_amp_ab));

      // ── rungler ──────────────────────────────────────
      data_bit = LFPulse.ar(rate_mod_a.abs.max(0.01) / grain_a.max(0.01), 0, 0.5);
      clock_sig = LFPulse.ar(rate_mod_b.abs.max(0.01) / grain_b.max(0.01), 0, 0.5);

      trig = Trig1.ar(clock_sig - 0.5, SampleDur.ir);
      xor_bit = (data_bit + prev_last) - (2 * data_bit * prev_last);
      sh0 = ((1-chaos)*data_bit) + (chaos*xor_bit);
      sh0 = (sh0 > 0.5);
      sh1 = Latch.ar(sh0, trig);
      sh2 = Latch.ar(Delay1.ar(sh1), trig);
      sh3 = Latch.ar(Delay1.ar(sh2), trig);
      sh4 = Latch.ar(Delay1.ar(sh3), trig);
      sh5 = Latch.ar(Delay1.ar(sh4), trig);
      sh6 = Latch.ar(Delay1.ar(sh5), trig);
      sh7 = Latch.ar(Delay1.ar(sh6), trig);

      rungler_cv = Select.ar(loop_len.clip(3,8).round - 3, [
        (sh1*0.25)+(sh2*0.5)+(sh3*1.0),
        (sh2*0.25)+(sh3*0.5)+(sh4*1.0),
        (sh3*0.25)+(sh4*0.5)+(sh5*1.0),
        (sh4*0.25)+(sh5*0.5)+(sh6*1.0),
        (sh5*0.25)+(sh6*0.5)+(sh7*1.0),
        (sh6*0.25)+(sh7*0.5)+(sh1*1.0),
      ]);
      rung = (rungler_cv / 1.75) * 2 - 1;
      // feed back: rung CV, last shift register bit, mixed sample audio
      LocalOut.ar([rung, sh7, (sig_a[0] + sig_b[0]) * 0.5]);
      Out.kr(rung_bus, A2K.kr(rung));

      // ── stereo mix ───────────────────────────────────
      mix_l = (sig_a[0] * (1 - spread*0.3)) + (sig_b[0] * spread * 0.3)
            + (sig_a[1] * spread * 0.2) + (sig_b[1] * (1 - spread*0.3));
      mix_r = (sig_a[1] * (1 - spread*0.3)) + (sig_b[1] * spread * 0.3)
            + (sig_a[0] * spread * 0.2) + (sig_b[0] * (1 - spread*0.3));

      // ── filter ───────────────────────────────────────
      filt_in = (mix_l + mix_r) * 0.5;
      f_freq = (filt_freq + (rung * run_f * filt_freq)).clip(20, 20000);
      f_lp = RLPF.ar(filt_in, f_freq, filt_res.clip(0.05, 2));
      f_bp = BPF.ar(filt_in, f_freq, filt_res.clip(0.05, 2));
      f_hp = HPF.ar(filt_in, f_freq);
      f_tp = (BPF.ar(filt_in, f_freq, filt_res.clip(0.05,2))
            + BPF.ar(filt_in, (f_freq*filt_peak2).clip(20,20000), filt_res.clip(0.05,2))) * 0.7;
      filt_out = Select.ar(filt_type.round.clip(0,3), [f_lp, f_bp, f_hp, f_tp]);

      // apply filter to stereo (preserve stereo image)
      out_l = (mix_l * (1-filt_mix)) + (filt_out * filt_mix);
      out_r = (mix_r * (1-filt_mix)) + (filt_out * filt_mix);

      // ── comb filter (rungler-modulated, stereo) ────────
      comb_sig = CombC.ar(out_l + out_r, 0.1,
        (1 / (comb_freq + (rung * run_f * comb_freq * 0.3)).max(20)).clip(0.00002, 0.1),
        comb_fb * 5) * 0.4;
      // stereo comb: slightly detuned second comb
      out_l = (out_l * (1-comb_mix)) + (CombC.ar(out_l, 0.1,
        (1 / (comb_freq * 1.003 + (rung * run_f * comb_freq * 0.25)).max(20)).clip(0.00002, 0.1),
        comb_fb * 5) * comb_mix * 0.5) + (comb_sig * comb_mix * 0.3);
      out_r = (out_r * (1-comb_mix)) + (CombC.ar(out_r, 0.1,
        (1 / (comb_freq * 0.997 + (rung * run_f * comb_freq * 0.25)).max(20)).clip(0.00002, 0.1),
        comb_fb * 5) * comb_mix * 0.5) + (comb_sig * comb_mix * 0.3);

      // ── pan ──────────────────────────────────────────
      pan_sig = Select.kr(pan_mode.round.clip(0,2), [
        DC.kr(0),
        A2K.kr(rung) * pan_width,
        LFNoise1.kr(2.5) * pan_width
      ]).clip(-1, 1);
      // apply pan as balance shift
      out_l = out_l * (1 - pan_sig.max(0));
      out_r = out_r * (1 + pan_sig.min(0));

      // ── stereo delay ─────────────────────────────────
      dly_t = Lag.kr((dly_time + (A2K.kr(rung) * cv_dly * dly_time)).clip(0.001, 2), 0.05);
      dly_l = CombC.ar(out_l, 2.0, dly_t.clip(0.001,2), dly_fb*6) * 0.5;
      dly_r = CombC.ar(out_r, 2.0, (dly_t*1.06).clip(0.001,2), dly_fb*6) * 0.5;

      out_l = (out_l * (1-dly_mix)) + (dly_l * dly_mix);
      out_r = (out_r * (1-dly_mix)) + (dly_r * dly_mix);

      out_l = LeakDC.ar(out_l); out_r = LeakDC.ar(out_r);
      Out.kr(amp_bus, Amplitude.kr(out_l + out_r, 0.01, 0.1));
      Out.ar(0, Limiter.ar([out_l, out_r] * amp, 0.95, 0.01));
    }).add;

    context.server.sync;
    synth = Synth.new(\grainrungler, [
      \buf_a, bufA.bufnum, \buf_b, bufB.bufnum,
      \rung_bus, rungBus.index, \amp_bus, ampBus.index,
    ], target: context.xg);

    // load: read STEREO files
    this.addCommand(\load_a, "s", { |msg|
      bufA.free;
      bufA = Buffer.read(context.server, msg[1].asString, action: { |b|
        synth.set(\buf_a, b.bufnum, \len_a, b.numFrames / b.sampleRate);
      });
    });
    this.addCommand(\load_b, "s", { |msg|
      bufB.free;
      bufB = Buffer.read(context.server, msg[1].asString, action: { |b|
        synth.set(\buf_b, b.bufnum, \len_b, b.numFrames / b.sampleRate);
      });
    });

    [\pos_a,\rate_a,\grain_a,\level_a,\atk_a,\rel_a,\len_a,
     \jitter_a,\density_a,
     \pos_b,\rate_b,\grain_b,\level_b,\atk_b,\rel_b,\len_b,
     \jitter_b,\density_b,
     \run_a,\run_b,\run_f,\chaos,\gate_thresh,
     \xmod_pm_ab,\xmod_pm_ba,\xmod_amp_ab,\xmod_amp_ba,
     \filt_freq,\filt_res,\filt_peak2,\filt_mix,
     \comb_freq,\comb_fb,\comb_mix,
     \dly_time,\dly_fb,\dly_mix,\cv_dly,
     \spread,\amp,\pan_width
    ].do({ |key|
      this.addCommand(key, "f", { |msg| synth.set(key, msg[1]) });
    });

    [\loop_len,\filt_type,\pan_mode].do({ |key|
      this.addCommand(key, "i", { |msg| synth.set(key, msg[1]) });
    });

    this.addPoll(\poll_rung, { rungBus.getSynchronous });
    this.addPoll(\poll_amp,  { ampBus.getSynchronous });
  }

  free {
    if(synth.notNil){synth.free};
    if(bufA.notNil){bufA.free};
    if(bufB.notNil){bufB.free};
    if(rungBus.notNil){rungBus.free};
    if(ampBus.notNil){ampBus.free};
  }
}
