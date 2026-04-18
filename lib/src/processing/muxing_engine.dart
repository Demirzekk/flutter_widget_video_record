import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';
import 'package:flutter/foundation.dart';

class MuxingEngine {
  final int width;
  final int height;
  final int fps;

  String? _videoPipePath;
  IOSink? _videoPipeSink;
  StreamSubscription<Uint8List>? _frameSubscription;
  Future<void>? _ffmpegSession;

  MuxingEngine({
    required this.width,
    required this.height,
    this.fps = 30,
  });

  /// Starts the muxing process.
  /// [frameStream] is the stream of rawRgba frames.
  /// [audioPath] is the recorded audio file path.
  /// [outputPath] is the final mp4 file path.
  Future<void> startMuxing({
    required Stream<Uint8List> frameStream,
    required String audioPath,
    required String outputPath,
  }) async {
    try {
      // 1. Create a named pipe for video frames
      _videoPipePath = await FFmpegKitConfig.registerNewFFmpegPipe();
      if (_videoPipePath == null) {
        throw Exception("Failed to register FFmpeg pipe");
      }

      // 2. Open the pipe for writing
      final pipeFile = File(_videoPipePath!);
      _videoPipeSink = pipeFile.openWrite();

      // 3. Start listening to frames and writing them to the pipe
      _frameSubscription = frameStream.listen((Uint8List frameData) {
        _videoPipeSink?.add(frameData);
      }, onError: (e) {
        debugPrint("Frame stream error: $e");
      });

      // 4. Construct FFmpeg command
      // -f rawvideo -pix_fmt rgba -s widthxheight -r fps -i <pipe>
      // -i <audio>
      // -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -y <output>
      
      final String ffmpegCommand = 
        '-f rawvideo -pix_fmt rgba -s ${width}x$height -r $fps -i $_videoPipePath '
        '-i $audioPath '
        '-c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -y $outputPath';

      // 5. Run FFmpeg asynchronously
      debugPrint("Starting FFmpeg with command: $ffmpegCommand");
      _ffmpegSession = FFmpegKit.execute(ffmpegCommand).then((session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint("FFmpeg processing completed successfully.");
        } else if (ReturnCode.isCancel(returnCode)) {
          debugPrint("FFmpeg processing cancelled.");
        } else {
          final logs = await session.getLogsAsString();
          debugPrint("FFmpeg processing failed with rc=$returnCode.\nLogs: $logs");
        }
      });
    } catch (e) {
      debugPrint("Muxing error: $e");
      await stopMuxing();
      rethrow;
    }
  }

  /// Stops writing to the pipe, closes it, and waits for FFmpeg to finish.
  Future<void> stopMuxing() async {
    // Stop listening to new frames
    await _frameSubscription?.cancel();
    _frameSubscription = null;

    // Close the sink to send EOF to the pipe, so FFmpeg knows video is done
    await _videoPipeSink?.flush();
    await _videoPipeSink?.close();
    _videoPipeSink = null;

    // Wait for FFmpeg to finish processing the final file
    if (_ffmpegSession != null) {
      await _ffmpegSession;
      _ffmpegSession = null;
    }

    // Cleanup the pipe
    if (_videoPipePath != null) {
      // In newer versions, closeFFmpegPipe is available. 
      // If not, registering a pipe creates a temporary file that should be removed if needed, 
      // but ffmpeg kit manages its own pipes usually or we don't strictly need to delete it.
      _videoPipePath = null;
    }
  }
}
