# Metronome (iOS / SwiftUI)

A native iPhone metronome with a clean **white & green** theme.

## Features

- **Sample-accurate timing** using `AVAudioEngine` with a look-ahead scheduler
  (clicks are scheduled on the audio clock, so the tempo never drifts).
- **30–240 BPM** with a big readout, `+`/`−` steppers and a slider.
- **Tap tempo** — set the BPM by tapping along.
- **Time signatures** (1–8 beats) with an accented downbeat.
- **Subdivisions** — quarter, eighth, triplet, sixteenth.
- **Animated beat indicator** synced to the audio.
- Live Italian tempo markings (Largo, Andante, Allegro, …).

## Requirements

- Xcode 16 or newer
- iOS 17.0+

## Run it

1. Open `Metronome.xcodeproj` in Xcode.
2. Select an iPhone simulator (or your device).
3. Press **Run** (⌘R).

> If building to a physical device, set your own Team under
> *Signing & Capabilities* and adjust the bundle identifier
> (`com.timfogarty.Metronome`) if needed.

## Project layout

```
Metronome.xcodeproj
Metronome/
├── MetronomeApp.swift      App entry point
├── ContentView.swift       SwiftUI UI (white & green)
├── MetronomeEngine.swift   AVAudioEngine timing + click synthesis
└── Assets.xcassets         App icon + accent color
```
