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
  final StreamController<Uint8List> _frameStreamController = StreamController<Uint8List>.broadcast();

  CaptureEngine({
    required this.boundaryKey,
    this.fps = 30,
    this.pixelRatio = 1.0,
  });

  Stream<Uint8List> get frameStream => _frameStreamController.stream;
  bool get isCapturing => _isCapturing;

  void start() {
    if (_isCapturing) return;
    _isCapturing = true;

    final interval = Duration(milliseconds: 1000 ~/ fps);
    _timer = Timer.periodic(interval, (timer) {
      _captureFrame();
    });
  }

  void stop() {
    _timer?.cancel();
    _isCapturing = false;
  }

  void dispose() {
    stop();
    _frameStreamController.close();
  }

  Future<void> _captureFrame() async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      if (boundary.debugNeedsPaint) {
        // We might want to wait or just skip if it's not ready, 
        // but for high fps video, skipping a frame or repeating the last one is normal.
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      // Using rawRgba is significantly faster than png.
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      
      if (byteData != null && _isCapturing) {
        _frameStreamController.add(byteData.buffer.asUint8List());
      }
      
      image.dispose();
    } catch (e) {
      debugPrint("Frame capture error: $e");
    }
  }
}
