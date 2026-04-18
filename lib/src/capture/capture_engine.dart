import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class CaptureEngine {
  final GlobalKey boundaryKey;
  final int fps;
  final double pixelRatio;
  
  Timer? _timer;
  bool _isCapturing = false;
  bool _isProcessingFrame = false; // Guard: prevents frame pile-up
  final StreamController<Uint8List> _frameStreamController = StreamController<Uint8List>.broadcast();

  int _capturedFrames = 0;
  int _skippedFrames = 0;

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

    final interval = Duration(milliseconds: 1000 ~/ fps);
    _timer = Timer.periodic(interval, (timer) {
      _captureFrame();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isCapturing = false;
    debugPrint("CaptureEngine stats: captured=$_capturedFrames, skipped=$_skippedFrames");
  }

  void dispose() {
    stop();
    _frameStreamController.close();
  }

  Future<void> _captureFrame() async {
    // CRITICAL: If the previous frame is still being processed, SKIP this tick.
    // This prevents frame pile-up which is the #1 cause of UI jank.
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

      // toImage() is GPU readback — this is the expensive part.
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      
      if (byteData != null && _isCapturing) {
        _frameStreamController.add(byteData.buffer.asUint8List());
        _capturedFrames++;
      }
    } catch (e) {
      debugPrint("Frame capture error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }
}
