import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

import '../capture/capture_engine.dart';
import '../audio/audio_engine.dart';
import '../processing/muxing_engine.dart';

class WidgetRecorderController {
  final GlobalKey boundaryKey = GlobalKey();
  
  final int fps;
  final double pixelRatio;

  CaptureEngine? _captureEngine;
  AudioEngine? _audioEngine;
  MuxingEngine? _muxingEngine;

  bool _isRecording = false;
  String? _currentOutputPath;

  WidgetRecorderController({
    this.fps = 30,
    this.pixelRatio = 1.0,
  });

  bool get isRecording => _isRecording;

  /// Yalnızca mikrofon ve gerekiyorsa depolama iznini kontrol eder ve ister.
  /// Not: Widget kaydı doğrudan bellek üzerinden (RenderRepaintBoundary) yapıldığı için 
  /// Kamera veya Ekran Kaydı iznine gerek yoktur. Sadece ses için Mikrofon izni yeterlidir.
  Future<bool> checkAndRequestPermissions() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Starts recording the widget and audio.
  /// Returns [true] if recording started successfully, [false] if permissions were denied.
  Future<bool> start({
    /// Optional custom output path. If null, a temporary file is created.
    String? outputPath,
  }) async {
    if (_isRecording) return false;
    
    // Explicitly check permissions before doing anything
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      debugPrint("Microphone permission denied. Cannot start recording.");
      return false;
    }

    // Determine dimensions from the RenderRepaintBoundary
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("Widget is not rendered yet. Cannot start recording.");
    }
    final size = boundary.size;
    final int width = (size.width * pixelRatio).toInt();
    final int height = (size.height * pixelRatio).toInt();
    
    // Ensure width and height are even numbers (required by many h264 encoders)
    final int safeWidth = width % 2 == 0 ? width : width - 1;
    final int safeHeight = height % 2 == 0 ? height : height - 1;

    final tempDir = await getTemporaryDirectory();
    final uuid = const Uuid().v4();
    final tempAudioPath = '${tempDir.path}/audio_$uuid.m4a';
    _currentOutputPath = outputPath ?? '${tempDir.path}/video_$uuid.mp4';

    // Initialize engines
    _captureEngine = CaptureEngine(
      boundaryKey: boundaryKey,
      fps: fps,
      pixelRatio: pixelRatio,
    );
    
    _audioEngine = AudioEngine();
    _muxingEngine = MuxingEngine(
      width: safeWidth,
      height: safeHeight,
      fps: fps,
    );

    // 1. Start audio recording
    await _audioEngine!.startRecording(tempAudioPath);

    // 2. Start muxing
    await _muxingEngine!.startMuxing(
      frameStream: _captureEngine!.frameStream,
      audioPath: tempAudioPath,
      outputPath: _currentOutputPath!,
    );

    // 3. Start capturing frames
    _captureEngine!.start();
    
    _isRecording = true;
    return true;
  }

  /// Stops the recording and returns the path to the recorded video.
  Future<String?> stop() async {
    if (!_isRecording) return null;

    // 1. Stop capturing frames
    _captureEngine?.stop();

    // 2. Stop audio recording
    await _audioEngine?.stopRecording();

    // 3. Stop muxing (this will close the pipe and wait for FFmpeg to finish)
    await _muxingEngine?.stopMuxing();

    // Clean up
    _captureEngine?.dispose();
    _audioEngine?.dispose();

    _isRecording = false;
    return _currentOutputPath;
  }
}
