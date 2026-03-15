// lib/Engine_GrainFX.sc
// Minimal effects processor for grainrungler
// Reads softcut output from main bus, applies:
//   - state variable filter (LP/BP/HP/TwinPeak)
//   - delay with CV modulation input
// Writes processed audio back to main bus

Engine_GrainFX : CroneEngine {
  var <synth;

  *new { |context, doneCallback| ^super.new(context, doneCallback) }

  alloc {
    SynthDef(\grainfx, {
      arg filter_freq=2000, filter_res=0.5, filter_type=0,
          filter_peak2=1.5, filter_mix=1.0,
          delay_time=0, delay_fb=0,
          cv_to_filt=0, cv_to_dly_t=0, cv_to_dly_fb=0,
          cv_val=0, // rungler CV sent from Lua
          amp=1.0;

      var inL, inR, mono, filt_in;
      var f_freq, lp, bp, hp, tp, filtered;
      var dly_t, dly_fb_m, del_l, del_r;
      var out;

      // read softcut output from main bus
      inL = InFeedback.ar(0);
      inR = InFeedback.ar(1);

      // ── filter ───────────────────────────────────────
      filt_in = (inL + inR) * 0.5;
      f_freq = (filter_freq + (cv_val * cv_to_filt * filter_freq)).clip(20, 20000);

      lp = RLPF.ar(filt_in, f_freq, filter_res.clip(0.05, 2));
      bp = BPF.ar(filt_in, f_freq, filter_res.clip(0.05, 2));
      hp = HPF.ar(filt_in, f_freq);
      tp = (BPF.ar(filt_in, f_freq, filter_res.clip(0.05, 2))
          + BPF.ar(filt_in, (f_freq * filter_peak2).clip(20, 20000),
                   filter_res.clip(0.05, 2))) * 0.7;

      filtered = Select.ar(filter_type.round.clip(0, 3), [lp, bp, hp, tp]);

      // crossfade dry/filtered
      out = (filt_in * (1 - filter_mix)) + (filtered * filter_mix);

      // ── delay (CV modulated) ─────────────────────────
      dly_t = Lag.kr((delay_time + (cv_val * cv_to_dly_t * delay_time)).clip(0.001, 2), 0.05);
      dly_fb_m = (delay_fb + (cv_val * cv_to_dly_fb * 0.5)).clip(0, 0.95);

      del_l = CombC.ar(out, 2.0,
        (dly_t * 1.03).clip(0.001, 2), dly_fb_m * 6) * 0.35 * (delay_time > 0.001);
      del_r = CombC.ar(out, 2.0,
        (dly_t * 0.97).clip(0.001, 2), dly_fb_m * 6) * 0.35 * (delay_time > 0.001);

      // replace main bus output
      ReplaceOut.ar(0, [
        (out + del_l) * amp,
        (out + del_r) * amp
      ]);
    }).add;

    context.server.sync;
    synth = Synth.new(\grainfx, [], target: context.xg);

    // float commands
    [\filter_freq, \filter_res, \filter_peak2, \filter_mix,
     \delay_time, \delay_fb,
     \cv_to_filt, \cv_to_dly_t, \cv_to_dly_fb,
     \cv_val, \amp
    ].do({ |key|
      this.addCommand(key, "f", { |msg| synth.set(key, msg[1]) });
    });

    // int commands
    [\filter_type].do({ |key|
      this.addCommand(key, "i", { |msg| synth.set(key, msg[1]) });
    });
  }

  free {
    if (synth.notNil) { synth.free };
  }
}
