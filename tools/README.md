# Audio Mixer Lab

`interference_mixer_lab.py` is a local interactive test bench for the Live
Radio stream/interference mix. It is not part of the Arma 3 addon runtime.

## Run

```bash
python3 tools/interference_mixer_lab.py
```

The lab needs Python Tk, NumPy, FFmpeg and ALSA `aplay`. It decodes the three
interference MP3 files from `resources/` and sends stereo PCM to the local audio
device.

## Controls

- `Stream URL`: HTTP(S) audio stream used as the program source. `Start stream`
  reloads it. If empty, the lab uses a synthetic stereo program.
- `TFAR factor`: normalized reception degradation input, from `0` to `1`.
- `Distance (m)`: current listener distance used by the cone simulation.
- `Distance bounds near`: close distance to the tower. The cone factor is `1`
  and the final volumes apply here.
- `Distance bounds far`: outer distance of the tower/cone. The cone factor is
  `0` and the initial volumes apply here.
- `Stream volume`: fixed base volume of the program stream.
- `Stream initial (far)`: stream volume at `Distance bounds far`.
- `Stream final (near)`: stream volume at `Distance bounds near`.
- `Interference initial (far)`: static volume at the far boundary.
- `Interference final (near)`: static volume at the near boundary.
- `Cone 1`, `Cone 2`, `Cone 3`: independent cone contributions. They are added
  together and clamped to `1`; they are not assigned to left/right speakers.
- `Enable hi/low-pass filters`: bypasses the filter stage while preserving the
  stream and static mix. With filters enabled, the filter is progressive: at
  factor `0` it is neutral, and at factor `1` it reaches approximately 800 Hz
  high-pass and 2,000 Hz low-pass.

The status line shows the current distance, near/far limits, effective factor,
volume endpoints and filter state.

## Stereo Behavior

The program stream is decoded as two-channel PCM. Each interference resource is
also decoded as stereo and its left/right channels are preserved. The three
interference resources are mixed into both output channels according to their
cone levels; using a different resource per speaker is intentionally avoided so
the result does not sound artificially panned.

The lab uses the same conceptual rules as the Rust mixer, but it is a listening
tool for choosing values. It does not replace in-game validation with a rebuilt
Live Radio DLL.

## Addon Equivalence

The corresponding in-game CBA settings are `Enable Hi/Low-Pass Filters`,
`Stream Initial Volume`, `Stream Final Volume`, `Interference Initial Volume`
and `Interference Final Volume`. Tower cone radius, cone enable and cone volume
settings provide the lab's `Distance bounds` and `Cone 1..3` values. The SQF
tick sends these values through the `source:mix_config` command to each local
Rust source.
