import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class CaptureEngine {
  final GlobalKey boundaryKey;
  final int fps;
  final double pixelRatio;
  
  Timer? _captureTimer;
  Timer? _pushTimer;
  final Stopwatch _stopwatch = Stopwatch();

  bool _isCapturing = false;
  bool _isProcessingFrame = false; 
  final StreamController<Uint8List> _frameStreamController = StreamController<Uint8List>.broadcast();

  Uint8List? _lastFrameBytes;
  int _capturedFrames = 0;
  int _skippedFrames = 0;
  int _pushedFrames = 0;

  CaptureEngine({
    required this.boundaryKey,
    this.fps = 30,
    this.pixelRatio = 1.0,
  });

  Stream<Uint8List> get frameStream => _frameStreamController.stream;
  bool get isCapturing => _isCapturing;
  int get capturedFrames => _capturedFrames;
  int get skippedFrames => _skippedFrames;

  void start() {
    if (_isCapturing) return;
    _isCapturing = true;
    _capturedFrames = 0;
    _skippedFrames = 0;
    _pushedFrames = 0;
    _lastFrameBytes = null;

    _stopwatch.reset();
    _stopwatch.start();

    // 1. Capture Loop: Attempts to capture frames from the UI independently
    final captureInterval = Duration(milliseconds: 1000 ~/ fps);
    _captureTimer = Timer.periodic(captureInterval, (timer) {
      _captureFrame();
    });

    // 2. Sync Push Loop: Guarantees EXACTLY `fps` frames per second are pushed
    // so the video length perfectly matches real time.
    _pushTimer = Timer.periodic(const Duration(milliseconds: 5), (timer) {
      _syncPushFrame();
    });
  }

  void stop() {
    _captureTimer?.cancel();
    _pushTimer?.cancel();
    _captureTimer = null;
    _pushTimer = null;
    _stopwatch.stop();
    _isCapturing = false;
    debugPrint("CaptureEngine stats: captured=$_capturedFrames, skipped=$_skippedFrames, pushed=$_pushedFrames");
  }

  void pause() {
    if (!_isCapturing) return;
    _isCapturing = false;
    _stopwatch.stop();
    _captureTimer?.cancel();
    _pushTimer?.cancel();
    _captureTimer = null;
    _pushTimer = null;
    debugPrint("CaptureEngine PAUSED");
  }

  void resume() {
    if (_isCapturing) return;
    _isCapturing = true;
    _stopwatch.start();

    // Restart timers exactly as in start()
    final captureInterval = Duration(milliseconds: 1000 ~/ fps);
    _captureTimer = Timer.periodic(captureInterval, (timer) {
      _captureFrame();
    });

    _pushTimer = Timer.periodic(const Duration(milliseconds: 5), (timer) {
      _syncPushFrame();
    });
    debugPrint("CaptureEngine RESUMED");
  }

  void dispose() {
    stop();
    _frameStreamController.close();
  }

  void _syncPushFrame() {
    if (!_isCapturing) return;

    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final targetFrames = (elapsedMs * fps) ~/ 1000;

    // Push frames if we are behind the real-time target
    while (_pushedFrames < targetFrames) {
      if (_lastFrameBytes != null) {
        _frameStreamController.add(_lastFrameBytes!);
        _pushedFrames++;
      } else {
        // If we haven't captured the first frame yet, wait.
        // Once the first frame comes in, it will catch up and duplicate it for the initial milliseconds.
        break;
      }
    }
  }

  Future<void> _captureFrame() async {
    // Prevent UI thread pile-up if the previous GPU readback hasn't finished
    if (_isProcessingFrame) {
      _skippedFrames++;
      return;
    }

    _isProcessingFrame = true;
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !_isCapturing) {
        _isProcessingFrame = false;
        return;
      }

      // GPU readback — expensive
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      
      if (byteData != null && _isCapturing) {
        _lastFrameBytes = byteData.buffer.asUint8List();
        _capturedFrames++;
      }
    } catch (e) {
      debugPrint("Frame capture error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }
}
