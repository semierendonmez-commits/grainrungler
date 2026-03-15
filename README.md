# grainrungler

a sample-based benjolin for [norns](https://monome.org/docs/norns/). two samples replace two oscillators. the rungler shift register drives everything.

---

## the concept

Rob Hordijk's Benjolin uses two oscillators cross-modulating through a shift register. grainrungler replaces those oscillators with granular sample playback. sample A provides DATA for the shift register. sample B provides the CLOCK. the resulting chaotic "stepped havoc wave" feeds back into both samples' rate, position, and the filter.

additionally, the two samples cross-modulate each other: A's amplitude shapes B's rate (and vice versa), plus FM cross-modulation for truly organic timbral interaction.

```
SAMPLE A (BufRd) ─── pulse ──→ DATA ──┐
    ↕ amp cross-mod                    ├── 8-BIT SHIFT REGISTER
    ↕ FM cross-mod                     │
SAMPLE B (BufRd) ─── pulse ──→ CLOCK ─┘
                                       ↓
                                  RUNGLER CV
                                       │
                 ┌─────────────────────┼──────────────┐
                 ↓                     ↓              ↓
              Run A                  Run B          Run F
              (rate A)              (rate B)       (filter)
                                                      │
                                           TWIN PEAK FILTER
                                                      │
                                                   DELAY (mix)
                                                      │
                                                    OUTPUT
```

## features

- **SC engine**: all audio in SuperCollider — BufRd granular, shift register, filter, delay. no softcut limitations.
- **twin peak filter**: LP/BP/HP/Twin Peak with rungler-modulated cutoff
- **delay with mix**: dry/wet control (not send), rungler-modulated time
- **4 cross-mod paths**: A↔B amplitude cross-mod + A↔B FM cross-mod
- **per-grain envelope**: attack/release shaping for each sample independently
- **grain size**: directly controls loop region length — bigger grain = longer sound segment
- **spread**: stereo placement of grain voices, works for both samples

## controls

- **E1**: scroll parameters (K1+E1: change page)
- **E2**: adjust selected parameter
- **E3**: adjust next parameter
- **K2**: toggle selected sample (A ↔ B)
- **K3**: load sample (GRAINS page) / randomize (other pages)

## pages

**GRAINS** — dual sample display with unique waveforms, position markers, grain windows, cross-mod indicators

**RUNGLER** — CV bar with threshold, chaos mode, run depths, CV history trace

**FILTER** — filter curve with twin peak support, real-time cutoff modulation, mix indicator

**FX** — cross-modulation depths (amp + FM), delay params with mix and CV modulation

## requirements

- norns (shield, standard, or fates)
- audio samples (wav/aif) in dust/audio
- no sc3-plugins needed (vanilla SuperCollider UGens only)

## install

```
;install https://github.com/semi/grainrungler
```

## license

MIT
