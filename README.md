# Flutter Widget Video Record

A high-performance Flutter package that allows you to record any Flutter Widget (using `RepaintBoundary`) to a high-quality video (MP4/MKV) at a high frame rate (e.g., 30/60 FPS) while simultaneously capturing audio from the microphone.

## Features

- **Widget Recording**: Record specific UI elements or the entire screen without requiring native screen-recording permissions.
- **High Performance**: Uses `rawRgba` data extraction and Named Pipes instead of writing heavy PNG sequences to disk.
- **Synchronized Audio**: Automatically records microphone audio and muxes it with the video.
- **FFmpeg Powered**: Highly customizable encoding via `ffmpeg_kit_flutter`.

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_widget_video_record:
    path: ./ # Or your git repository / pub.dev version
```

### Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access to record audio with the widget video.</string>
```

> **Note**: Because the capture happens entirely within the Flutter Engine's memory, you **do not** need Camera or Screen Recording permissions.

## Usage

### 1. Initialize the Controller

Create a `WidgetRecorderController` in your stateful widget.

```dart
import 'package:flutter_widget_video_record/flutter_widget_video_record.dart';

late final WidgetRecorderController _controller;

@override
void initState() {
  super.initState();
  // Set your desired FPS and pixel ratio
  _controller = WidgetRecorderController(fps: 30, pixelRatio: 1.0);
}
```

### 2. Wrap your target Widget

Wrap the widget you want to record with `WidgetRecorder` and pass the controller.

```dart
WidgetRecorder(
  controller: _controller,
  child: Container(
    width: 300,
    height: 300,
    color: Colors.blue,
    child: const Center(child: Text("Recording Target")),
  ),
)
```

### 3. Start and Stop Recording

```dart
// Start Recording
final success = await _controller.start();
if (!success) {
  print("Microphone permission denied or recording already in progress!");
}

// Stop Recording
final videoPath = await _controller.stop();
if (videoPath != null) {
  print("Video saved to: $videoPath");
}
```

## How it Works

1. **Capture Engine**: Extracts `rawRgba` frames from the `RenderRepaintBoundary` at the requested FPS.
2. **Audio Engine**: Records audio asynchronously to an `.m4a` file using the `record` package.
3. **Muxing Engine**: Pipes the `rawRgba` frames into an FFmpeg process in real-time, muxing them with the audio file into an MP4 video.
