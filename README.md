# grainrungler

a sample-based benjolin for [norns](https://monome.org/docs/norns/). two samples replace two oscillators. the rungler shift register drives everything into chaos. pure softcut and Lua — no SuperCollider engine needed.

---

## the idea

the hardware Benjolin has two oscillators that cross-modulate through a shift register. here, grain playback from two samples replaces those oscillators. sample A's grain phase wrapping generates DATA pulses. sample B generates CLOCK pulses. the rungler's stepped havoc wave feeds back into both samples' rate, position, and the filter.

additionally, the samples cross-modulate each other: A's amplitude envelope shapes B's parameters, and B shapes A.

```
SAMPLE A grains ─── DATA ───┐
    ↕ amplitude              ├── SHIFT REGISTER ── 3-BIT DAC ── RUNGLER CV
SAMPLE B grains ─── CLOCK ──┘                                      │
    ↕ amplitude                                                     │
    ↕ cross-mod (A↔B)                                              │
    │                        ┌──────────────────────────────────────┤
    ↓                        ↓                    ↓                 ↓
  grain params           Run A (rate)         Run B (rate)      Run F (filter)
                                                                    │
                                                              ┌─────┤
                                                              ↓     ↓
                                                         FILTER   DELAY
                                                         (softcut) (softcut)
```

## features

- **dual-sample granular** with independent position, rate, grain size, level, attack, release per sample
- **cross-modulation**: A amplitude → B parameters, B amplitude → A parameters
- **per-grain envelope**: attack/release shaping prevents flat, static textures
- **softcut filter**: LP/BP/HP with rungler-modulated cutoff
- **softcut delay**: implemented via level_cut_cut voice routing with configurable send, feedback, and rungler modulation
- **sample waveform display**: each loaded sample shows a unique visual based on its filename (not a generic sine wave)
- **source blend**: crossfade between sample-driven and internal oscillator-driven rungler

## controls

- **E1**: scroll parameters (K1+E1: change page)
- **E2**: adjust selected parameter
- **E3**: adjust next parameter
- **K2 short**: toggle selected sample (A ↔ B)
- **K2 long**: stop recording
- **K3**: load sample (GRAINS page) / randomize (other pages)
- **K1+K3**: record live input into selected sample buffer

## pages

**GRAINS** — dual sample display with unique waveforms, position markers, grain windows, pulse indicators, cross-mod depth display

**RUNGLER** — shift register, CV bar, run depth readouts, mini attractor scope

**FILTER** — filter curve with real-time cutoff modulation, type label, mix indicator

**FX** — cross-modulation depths, delay parameters with CV modulation display

## install

```
;install https://github.com/semi/grainrungler
```

## requirements

- norns (shield, standard, or fates)
- audio samples (wav/aif)
- no additional libraries or SuperCollider plugins

## license

MIT
