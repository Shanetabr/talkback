# Talkback

> This was the first prototype. It grew into
> [LiveCue](https://github.com/Shanetabr/LiveCue), which handles several channels
> at once and turns spoken keywords into show-control cues.

A small macOS app that turns one audio input channel into a live,
on-device speech-to-text transcript.

I'm building it for my church's production team. We're a small church
and can't afford the paid tools that do this, so Talkback is free and
open source.

## Status

Early: **v0.1**. It does one thing so far (see the roadmap).

## Features

- Pick any input device and one of its channels (for example, one
  channel of a multi-channel interface).
- Live transcript with timestamps. A changing gray guess shows while
  someone is speaking, then it settles into a line.
- Speech recognition runs on the Mac with Apple's `SpeechAnalyzer` and
  `SpeechTranscriber`. No audio is sent anywhere. The English speech
  model is downloaded from Apple once, the first time you start.
- Level meter for the chosen channel.
- The transcript follows the newest line. Scroll up to read back, then
  press **Jump to live**.
- **Clear** empties the transcript. **Space** starts and stops.
- Command-line check, with no window or microphone needed:
  `Talkback --file speech.wav [channel]` prints what it hears in a
  sound file.

## Requirements

- macOS 26 (Tahoe) or later
- Swift 6 toolchain (Xcode 26 or its command-line tools) to build
- Microphone and speech recognition permission. macOS asks the first
  time you press Start.

## Build

```sh
./build.sh
open dist/Talkback.app
```

`build.sh` builds a release binary and puts it in `dist/Talkback.app`,
signed ad hoc for this Mac. To run without making an app bundle:

```sh
swift run Talkback
```

## Roadmap

- [x] One input channel to a live transcript
- [ ] Multiple channels
- [ ] Spoken cues to MIDI

## License

MIT. See [LICENSE](LICENSE).
