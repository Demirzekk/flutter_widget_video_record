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

  String? _tempVideoPath;
  String? _tempAudioPath;

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

    // Determine exact dimensions by capturing a dummy frame
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("Widget is not rendered yet. Cannot start recording.");
    }
    
    final dummyImage = await boundary.toImage(pixelRatio: pixelRatio);
    final int actualWidth = dummyImage.width;
    final int actualHeight = dummyImage.height;
    dummyImage.dispose(); // free memory

    final tempDir = await getTemporaryDirectory();
    final uuid = const Uuid().v4();
    _tempAudioPath = '${tempDir.path}/audio_$uuid.m4a';
    _tempVideoPath = '${tempDir.path}/video_temp_$uuid.mp4';
    _currentOutputPath = outputPath ?? '${tempDir.path}/video_$uuid.mp4';

    // Initialize engines
    _captureEngine = CaptureEngine(
      boundaryKey: boundaryKey,
      fps: fps,
      pixelRatio: pixelRatio,
    );
    
    _audioEngine = AudioEngine();
    _muxingEngine = MuxingEngine(
      width: actualWidth,
      height: actualHeight,
      fps: fps,
    );

    // 1. Start audio recording
    await _audioEngine!.startRecording(_tempAudioPath!);

    // 2. Start video encoding via pipe
    await _muxingEngine!.startVideoEncoding(
      frameStream: _captureEngine!.frameStream,
      tempVideoPath: _tempVideoPath!,
    );

    // 3. Start capturing frames
    _captureEngine!.start();
    
    _isRecording = true;
    return true;
  }

  /// Stops the recording and returns the path to the recorded video.
  Future<String?> stop() async {
    if (!_isRecording) return null;

    debugPrint("--- STOP RECORDING INITIATED ---");
    // 1. Stop capturing frames
    debugPrint("Stopping capture engine...");
    _captureEngine?.stop();

    // 2. Stop audio recording (Finalizes the audio file)
    debugPrint("Stopping audio engine...");
    await _audioEngine?.stopRecording();

    // 3. Stop video encoding (Closes the pipe and waits for FFmpeg to finish encoding video)
    debugPrint("Stopping video encoding...");
    await _muxingEngine?.stopVideoEncoding();

    // 4. Combine Video and Audio
    if (_tempVideoPath != null && _tempAudioPath != null && _currentOutputPath != null) {
      debugPrint("Combining video and audio...");
      await _muxingEngine?.combineVideoAndAudio(
        videoPath: _tempVideoPath!,
        audioPath: _tempAudioPath!,
        outputPath: _currentOutputPath!,
      );
    }

    // Clean up
    debugPrint("Cleaning up engines...");
    _captureEngine?.dispose();
    _audioEngine?.dispose();

    _isRecording = false;
    debugPrint("--- STOP RECORDING COMPLETE --- Output: $_currentOutputPath");
    return _currentOutputPath;
  }
}
