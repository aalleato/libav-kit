# libav-kit

A Swift package wrapping FFmpeg's C libraries for audio decoding, encoding, metadata reading, tag writing, and cover art embedding. Uses the C API directly — no CLI shelling.

## Requirements

- macOS 14.4+
- Swift 6.2+
- FFmpeg development libraries (`brew install ffmpeg`)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "git@github.com:nycjv321/libav-kit.git", branch: "main"),
]
```

Then add `LibAVKit` as a dependency to your target:

```swift
.target(name: "MyTarget", dependencies: [
    .product(name: "LibAVKit", package: "libav-kit"),
])
```

## API Overview

### Decoding

**FFmpegDecoder** decodes audio files to PCM buffers for playback.

```swift
let decoder = FFmpegDecoder()
decoder.configure(outputFormat: .cdQuality)
try decoder.open(url: audioFileURL)

while let buffer = decoder.decodeNextBuffer() {
    // Process PCM buffer
}

decoder.close()
```

Properties available after `open()`: `duration`, `sampleRate`, `channels`, `bitrate`, `codecName`, `bitsPerSample`, `sourceFormat`.

### Encoding

**FFmpegEncoder** encodes PCM audio to compressed or lossless formats.

```swift
let encoder = FFmpegEncoder()
let config = ConversionConfig(
    outputFormat: .flac,
    encodingSettings: .flac(FLACEncodingSettings(compressionLevel: 5))
)

try encoder.encode(
    inputURL: sourceFile,
    outputURL: outputFile,
    config: config,
    progress: { percent in print("\(Int(percent * 100))%") },
    isCancelled: { false }
)
```

Supported formats (runtime-checked via FFmpeg availability):

| Format | Lossless | Settings |
|--------|----------|----------|
| FLAC | Yes | Compression level (0-8) |
| ALAC | Yes | — |
| WAV | Yes | — |
| AIFF | Yes | — |
| WavPack | Yes | — |
| MP3 | No | CBR/VBR/ABR, bitrate, VBR quality |
| AAC | No | LC/HE-AAC/HE-AACv2, bitrate |
| Opus | No | Bitrate |
| Vorbis | No | Quality (0-10) |

### Metadata Reading

**MetadataReader** extracts metadata from audio files.

```swift
let reader = MetadataReader()
let metadata = try reader.read(url: audioFileURL)

print(metadata.title)       // "Song Title"
print(metadata.sampleRate)  // 44100
print(metadata.codec)       // "flac"
print(metadata.isAtmos)     // false
```

Reads: title, artist, album, albumArtist, year, trackNumber, discNumber, genre, duration, codec, bitrate, sampleRate, bitDepth, channels, coverArt, Atmos detection (E-AC-3 JOC, TrueHD).

### Tag Writing

**CFFmpegTagWriter** writes metadata to audio files via stream-copy remux (no re-encoding).

```swift
let writer = CFFmpegTagWriter()
let changes = MetadataChanges(
    title: "New Title",
    artistName: "New Artist",
    genre: "Jazz"
)

try writer.write(to: audioFileURL, changes: changes)
```

Supports extended tags (COMPOSER, CONDUCTOR, etc.) and custom tags. Atomic file replacement ensures crash safety.

### Cover Art Embedding

**CoverArtEmbedder** embeds or removes cover art using the C library (no CLI).

```swift
let embedder = CoverArtEmbedder()

// Embed
try embedder.embed(in: audioFileURL, imageData: jpegData, isOggContainer: false)

// Remove
try embedder.remove(from: audioFileURL)
```

Handles two embedding modes automatically:
- **OGG containers** (Opus, Vorbis): METADATA_BLOCK_PICTURE Vorbis comment
- **All others** (FLAC, MP3, AAC, etc.): Attached picture video stream

## Models

### OutputFormat

Target codec for encoding. Each case maps to a file extension and container format.

### ConversionConfig

Complete conversion specification: output format, encoding settings, optional sample rate/bit depth/channel overrides, and destination path.

Factory methods for common configurations:

```swift
let mp3Config = ConversionConfig.MP3.cbr(bitrate: 320)
let mp3Vbr = ConversionConfig.MP3.vbr(quality: 2)
```

### EncodingSettings

Discriminator-based polymorphic enum with per-codec settings. Codable with a `"type"` key for JSON serialization:

```json
{"type": "mp3", "settings": {"bitrateMode": "vbr", "bitrateKbps": 320, "vbrQuality": 2}}
```

### AudioOutputFormat

Playback target format specifying sample rate, channel count, sample format, and interleaving.

### EncodingProfile

Named, reusable encoding configuration with output format, settings, and optional path template.

## Architecture

```
LibAVKit
├── CFFmpeg (system library, internal — not re-exported)
├── Models/          Value types: OutputFormat, ConversionConfig, EncodingSettings, etc.
├── Decoding/        FFmpegDecoder, MetadataReader
├── Encoding/        FFmpegEncoder, FFmpegEncoderConfig, EncoderMetadataWriter
├── TagWriting/      CFFmpegTagWriter
├── ArtEmbedding/    CoverArtEmbedder
└── Utilities/       VorbisPictureBlock, CustomTagParser
```

CFFmpeg wraps the raw C libraries and is **not re-exported** — only the Swift API is public.

## License

MIT. See [LICENSE](LICENSE).

Note: This package links against FFmpeg, which is licensed under LGPL 2.1+ (or GPL depending on configuration). Ensure your FFmpeg build and usage comply with its license terms.
