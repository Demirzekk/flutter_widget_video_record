# Flutter Widget Video Record

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A high-performance Flutter package that records any widget to an **MP4 video with audio** — without requiring native screen-recording or camera permissions.

Ideal for **smart board / whiteboard apps**, drawing tools, educational platforms, and any scenario where you need to capture on-screen content as a video.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎯 **Widget-Level Recording** | Record a specific widget or the entire screen via `RepaintBoundary` |
| 🎤 **Synchronized Audio** | Captures microphone audio and muxes it with the video automatically |
| ⚡ **High Performance** | Frame-skipping guard prevents UI jank; uses raw RGBA + named pipes (no PNG sequences) |
| 🔒 **No Special Permissions** | No Camera or Screen Recording permission needed — only Microphone |
| 🎬 **FFmpeg Powered** | Two-step encoding: video → audio → combine. Future-ready for cropping, overlays, and more |
| 📐 **Configurable Quality** | Adjustable FPS, pixel ratio, and output path |

## 📦 Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_widget_video_record:
    git:
      url: https://github.com/Demirzekk/flutter_widget_video_record.git
```

### Platform Permissions

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed to record audio with the widget video.</string>
```

> **Note:** Because frame capture happens entirely within the Flutter engine's memory (`RenderRepaintBoundary.toImage`), you do **not** need Camera or Screen Recording permissions.

---

## 🚀 Quick Start

### 1. Create a Controller

```dart
import 'package:flutter_widget_video_record/flutter_widget_video_record.dart';

// In your StatefulWidget:
late WidgetRecorderController _controller;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 1.5);
  _controller = WidgetRecorderController(fps: 30, pixelRatio: pixelRatio);
}
```

#### Controller Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fps` | `int` | `30` | Frames per second. 30 is recommended for smart boards |
| `pixelRatio` | `double` | `1.0` | Rendering scale factor. Cap at 1.5 for performance |

### 2. Wrap Your Target Widget

```dart
WidgetRecorder(
  controller: _controller,
  child: MyDrawingCanvas(), // Any widget you want to record
)
```

The `WidgetRecorder` wraps your widget with a `RepaintBoundary` and links it to the controller. **Only the content inside this widget will be captured.**

### 3. Start & Stop Recording

```dart
// Start recording
final success = await _controller.start();
if (!success) {
  print('Microphone permission denied!');
}

// Stop recording — returns the output file path
final videoPath = await _controller.stop();
if (videoPath != null) {
  print('Video saved to: $videoPath');
}
```

### 4. Custom Output Path (Optional)

```dart
final success = await _controller.start(
  outputPath: '/storage/emulated/0/Download/my_recording.mp4',
);
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                  WidgetRecorder                      │
│              (RepaintBoundary wrapper)                │
└──────────────┬──────────────────────────────────────┘
               │
       ┌───────▼───────┐
       │ CaptureEngine  │  Timer.periodic → toImage() → rawRgba bytes
       │ (Frame Skip    │  Skips tick if previous frame still processing
       │  Guard)        │
       └───────┬───────┘
               │ Stream<Uint8List>
       ┌───────▼───────┐       ┌──────────────┐
       │ MuxingEngine   │       │ AudioEngine   │
       │ (Named Pipe →  │       │ (record pkg → │
       │  FFmpeg encode) │       │  .m4a file)   │
       └───────┬───────┘       └──────┬───────┘
               │                       │
               │  Step 1: video.mp4    │  Step 1: audio.m4a
               │                       │
       ┌───────▼───────────────────────▼───────┐
       │     FFmpeg Combine (copy, no re-encode) │
       │     → final_output.mp4                  │
       └─────────────────────────────────────────┘
```

### How It Works

1. **CaptureEngine** extracts `rawRgba` frames from `RenderRepaintBoundary` at the configured FPS. A **frame-skipping guard** ensures that if `toImage()` from the previous tick hasn't finished, the current tick is skipped — preventing frame pile-up and UI jank.

2. **AudioEngine** records microphone audio to a temporary `.m4a` file using the [`record`](https://pub.dev/packages/record) package.

3. **MuxingEngine** performs a two-step process:
   - **During recording:** Pipes raw frames through a named pipe to FFmpeg, which encodes them into a temporary silent `.mp4` (H.264, ultrafast preset).
   - **On stop:** Runs a second FFmpeg pass that combines the video and audio with **zero-quality-loss** (`-c:v copy`).

---

## ⚙️ Performance Tips

| Tip | Why |
|---|---|
| Keep `pixelRatio` ≤ 1.5 | Full device ratio (2.75–3.5) creates ~10MB/frame, causing GPU readback bottleneck |
| Use `fps: 30` for smart boards | 60 FPS doubles CPU load with minimal visual benefit for drawing apps |
| Avoid heavy `build()` during recording | Complex widget rebuilds compete with `toImage()` for the raster thread |
| Check `CaptureEngine.skippedFrames` | High skip count means your content is too heavy for the target FPS |

---

## 📋 Dependencies

| Package | Purpose |
|---|---|
| [`ffmpeg_kit_flutter_new`](https://pub.dev/packages/ffmpeg_kit_flutter_new) | Video encoding & muxing (Full-GPL, supports future overlays/cropping) |
| [`record`](https://pub.dev/packages/record) | Microphone audio recording |
| [`path_provider`](https://pub.dev/packages/path_provider) | Temporary file paths |
| [`uuid`](https://pub.dev/packages/uuid) | Unique filenames for recordings |
| [`permission_handler`](https://pub.dev/packages/permission_handler) | Microphone permission management |

---

## 🗺️ Roadmap

- [ ] Video trimming / cropping
- [ ] Logo & watermark overlay
- [ ] Text banner / top bar overlay
- [ ] Built-in video editor screen
- [ ] Export quality presets (Low / Medium / High / Custom)
- [ ] Web platform support

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
