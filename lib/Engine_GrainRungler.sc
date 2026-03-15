// lib/Engine_GrainRungler.sc
// Sample-based Benjolin: 2 samples + rungler + twin peak filter + delay
// All audio processing in SC. Samples loaded via Buffer.read.
// Grain playback via BufRd + Phasor.

Engine_GrainRungler : CroneEngine {
  var <synth;
  var <bufA, <bufB;
  var rungBus, ampBus;

  *new { |context, doneCallback| ^super.new(context, doneCallback) }

  alloc {
    // allocate stereo-capable mono buffers
    bufA = Buffer.alloc(context.server, 48000 * 60, 1); // 60s mono
    bufB = Buffer.alloc(context.server, 48000 * 60, 1);

    rungBus = Bus.control(context.server, 1);
    ampBus  = Bus.control(context.server, 1);

    SynthDef(\grainrungler, {
      arg buf_a=0, buf_b=0,
          // sample A grain params
          pos_a=0, rate_a=1, grain_a=0.12, level_a=0.8,
          atk_a=0.01, rel_a=0.05,
          len_a=1, // sample length in seconds (set by Lua)
          // sample B grain params
          pos_b=0, rate_b=0.25, grain_b=0.2, level_b=0.8,
          atk_b=0.01, rel_b=0.05,
          len_b=1,
          // rungler
          run_a=0.5, run_b=0.3, run_f=0.4,
          chaos=1, loop_len=8,
          gate_thresh=0.3,
          // cross-mod
          xmod_ab=0, xmod_ba=0, // amplitude cross-mod
          xmod_fm_ab=0, xmod_fm_ba=0, // frequency cross-mod
          // filter
          filt_freq=2000, filt_res=0.5, filt_type=0,
          filt_peak2=1.5, filt_mix=0.8,
          // delay
          dly_time=0, dly_fb=0, dly_mix=0,
          cv_dly=0, // rungler → delay time
          // master
          spread=0.5, amp=0.8,
          // buses
          rung_bus=0, amp_bus=0;

      // ── vars ─────────────────────────────────────────
      var phasor_a, phasor_b, phase_a, phase_b;
      var sig_a, sig_b, sig_a2, sig_b2;
      var amp_a, amp_b;
      var env_a, env_b;
      var rate_mod_a, rate_mod_b;
      var pos_samp_a, pos_samp_b;
      var grain_samp_a, grain_samp_b;
      var sh0, sh1, sh2, sh3, sh4, sh5, sh6, sh7;
      var data_bit, clock_sig, xor_bit, rungler_cv, rung, trig;
      var fb_sig, prev_rung, prev_last;
      var filt_in, f_freq, filt_out;
      var f_lp, f_bp, f_hp, f_tp;
      var mono_a, mono_b, mix_dry, mix_filt;
      var dly_t, dly_l, dly_r;
      var out_l, out_r;

      // ── feedback (rungler) ───────────────────────────
      fb_sig    = LocalIn.ar(2, 0);
      prev_rung = fb_sig[0];
      prev_last = fb_sig[1];

      // ── amplitude followers for cross-mod ────────────
      // (use previous frame's output for feedback)
      amp_a = fb_sig[0].abs * 0.5 + 0.5; // normalize 0..1
      amp_b = fb_sig[1].abs * 0.5 + 0.5;

      // ── grain rate modulation ────────────────────────
      rate_mod_a = rate_a * (1 + (prev_rung * run_a))
                 + (amp_b * xmod_ba * rate_a * 0.5)
                 + (fb_sig[1] * xmod_fm_ba * rate_a * 0.3);
      rate_mod_a = rate_mod_a.clip(-4, 4);

      rate_mod_b = rate_b * (1 + (prev_rung * run_b))
                 + (amp_a * xmod_ab * rate_b * 0.5)
                 + (fb_sig[0] * xmod_fm_ab * rate_b * 0.3);
      rate_mod_b = rate_mod_b.clip(-4, 4);

      // ── grain position ───────────────────────────────
      pos_samp_a = (pos_a + (prev_rung * run_a * 0.15)).wrap(0, 1) * len_a * 48000;
      pos_samp_b = (pos_b + (prev_rung * run_b * 0.15)).wrap(0, 1) * len_b * 48000;

      grain_samp_a = (grain_a * rate_mod_a.abs.max(0.01) * 48000).clip(960, len_a * 48000 * 0.5);
      grain_samp_b = (grain_b * rate_mod_b.abs.max(0.01) * 48000).clip(960, len_b * 48000 * 0.5);

      // ── phasors (grain scanners) ─────────────────────
      phasor_a = Phasor.ar(0, rate_mod_a * BufRateScale.kr(buf_a),
        (pos_samp_a - (grain_samp_a * 0.5)).max(0),
        (pos_samp_a + (grain_samp_a * 0.5)).min(BufFrames.kr(buf_a)));
      phasor_b = Phasor.ar(0, rate_mod_b * BufRateScale.kr(buf_b),
        (pos_samp_b - (grain_samp_b * 0.5)).max(0),
        (pos_samp_b + (grain_samp_b * 0.5)).min(BufFrames.kr(buf_b)));

      // normalized phase (0..1) for envelope + rungler pulse
      phase_a = LinLin.ar(phasor_a,
        (pos_samp_a - grain_samp_a*0.5).max(0),
        (pos_samp_a + grain_samp_a*0.5).min(BufFrames.kr(buf_a)),
        0, 1);
      phase_b = LinLin.ar(phasor_b,
        (pos_samp_b - grain_samp_b*0.5).max(0),
        (pos_samp_b + grain_samp_b*0.5).min(BufFrames.kr(buf_b)),
        0, 1);

      // ── grain envelope ───────────────────────────────
      env_a = Select.ar((phase_a < atk_a), [
        Select.ar((phase_a > (1 - rel_a)), [
          DC.ar(1),
          LinLin.ar(phase_a, 1 - rel_a, 1, 1, 0).max(0)
        ]),
        LinLin.ar(phase_a, 0, atk_a, 0, 1).max(0)
      ]);
      env_b = Select.ar((phase_b < atk_b), [
        Select.ar((phase_b > (1 - rel_b)), [
          DC.ar(1),
          LinLin.ar(phase_b, 1 - rel_b, 1, 1, 0).max(0)
        ]),
        LinLin.ar(phase_b, 0, atk_b, 0, 1).max(0)
      ]);

      // ── read buffers ─────────────────────────────────
      sig_a = BufRd.ar(1, buf_a, phasor_a, 1, 4) * env_a * level_a;
      sig_b = BufRd.ar(1, buf_b, phasor_b, 1, 4) * env_b * level_b;
      // second voice per sample (spread)
      sig_a2 = BufRd.ar(1, buf_a, phasor_a + (grain_samp_a * spread * 0.1), 1, 4) * env_a * level_a * 0.7;
      sig_b2 = BufRd.ar(1, buf_b, phasor_b + (grain_samp_b * spread * 0.1), 1, 4) * env_b * level_b * 0.7;

      // ── rungler ──────────────────────────────────────
      // A pulse → DATA, B pulse → CLOCK
      data_bit = LFPulse.ar(rate_mod_a.abs.max(0.01) / grain_a.max(0.01), 0, 0.5);
      clock_sig = LFPulse.ar(rate_mod_b.abs.max(0.01) / grain_b.max(0.01), 0, 0.5);

      trig = Trig1.ar(clock_sig - 0.5, SampleDur.ir);
      xor_bit = (data_bit + prev_last) - (2 * data_bit * prev_last);
      sh0 = ((1-chaos) * data_bit) + (chaos * xor_bit);
      sh0 = (sh0 > 0.5);

      sh1 = Latch.ar(sh0,            trig);
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
      // feedback: [rung, sig_b for amplitude tracking]
      LocalOut.ar([rung, sig_b]);
      Out.kr(rung_bus, A2K.kr(rung));

      // ── stereo mix (before filter) ───────────────────
      mono_a = sig_a + sig_a2;
      mono_b = sig_b + sig_b2;

      // ── filter (twin peak capable) ───────────────────
      filt_in = mono_a + mono_b;
      f_freq = (filt_freq + (rung * run_f * filt_freq)).clip(20, 20000);
      f_lp = RLPF.ar(filt_in, f_freq, filt_res.clip(0.05, 2));
      f_bp = BPF.ar(filt_in, f_freq, filt_res.clip(0.05, 2));
      f_hp = HPF.ar(filt_in, f_freq);
      f_tp = (BPF.ar(filt_in, f_freq, filt_res.clip(0.05,2))
            + BPF.ar(filt_in, (f_freq*filt_peak2).clip(20,20000), filt_res.clip(0.05,2))) * 0.7;
      filt_out = Select.ar(filt_type.round.clip(0,3), [f_lp, f_bp, f_hp, f_tp]);

      // filter mix
      mix_dry = filt_in * (1 - filt_mix);
      mix_filt = filt_out * filt_mix;

      // ── stereo output ────────────────────────────────
      out_l = (mix_dry + mix_filt) * 0.5
            + (sig_a * (0.5 - spread * 0.3))
            + (sig_b2 * spread * 0.3);
      out_r = (mix_dry + mix_filt) * 0.5
            + (sig_a2 * spread * 0.3)
            + (sig_b * (0.5 - spread * 0.3));

      // ── delay (with mix control) ─────────────────────
      dly_t = Lag.kr((dly_time + (A2K.kr(rung) * cv_dly * dly_time)).clip(0.001, 2), 0.05);

      dly_l = CombC.ar(out_l, 2.0, dly_t.clip(0.001,2), dly_fb*6) * 0.5;
      dly_r = CombC.ar(out_r, 2.0,
        (dly_t * 1.07).clip(0.001,2), dly_fb*6) * 0.5;

      out_l = (out_l * (1 - dly_mix)) + (dly_l * dly_mix);
      out_r = (out_r * (1 - dly_mix)) + (dly_r * dly_mix);

      out_l = LeakDC.ar(out_l);
      out_r = LeakDC.ar(out_r);
      Out.kr(amp_bus, Amplitude.kr(out_l + out_r, 0.01, 0.1));
      Out.ar(0, Limiter.ar([out_l, out_r] * amp, 0.95, 0.01));
    }).add;

    context.server.sync;

    synth = Synth.new(\grainrungler, [
      \buf_a, bufA.bufnum, \buf_b, bufB.bufnum,
      \rung_bus, rungBus.index, \amp_bus, ampBus.index,
    ], target: context.xg);

    // ── load commands ──────────────────────────────────
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

    // ── float commands ─────────────────────────────────
    [\pos_a,\rate_a,\grain_a,\level_a,\atk_a,\rel_a,\len_a,
     \pos_b,\rate_b,\grain_b,\level_b,\atk_b,\rel_b,\len_b,
     \run_a,\run_b,\run_f,\chaos,\gate_thresh,
     \xmod_ab,\xmod_ba,\xmod_fm_ab,\xmod_fm_ba,
     \filt_freq,\filt_res,\filt_peak2,\filt_mix,
     \dly_time,\dly_fb,\dly_mix,\cv_dly,
     \spread,\amp
    ].do({ |key|
      this.addCommand(key, "f", { |msg| synth.set(key, msg[1]) });
    });

    [\loop_len,\filt_type].do({ |key|
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
