import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
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

  /// Starts the muxing process for video only.
  /// Pipe writes are OS-buffered and non-blocking — no isolate needed.
  Future<void> startVideoEncoding({
    required Stream<Uint8List> frameStream,
    required String tempVideoPath,
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

      // 3. Listen to frames and write to pipe (non-blocking, OS-buffered)
      _frameSubscription = frameStream.listen((Uint8List frameData) {
        _videoPipeSink?.add(frameData);
      }, onError: (e) {
        debugPrint("Frame stream error: $e");
      });

      // 4. Construct FFmpeg command (Video Only)
      // Using -threads 2 to limit CPU usage on mobile
      final String ffmpegCommand =
          '-f rawvideo -pix_fmt rgba -s ${width}x$height -r $fps -i $_videoPipePath '
          '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" '
          '-c:v libx264 -preset ultrafast -crf 23 -threads 2 -pix_fmt yuv420p -y $tempVideoPath';

      // 5. Run FFmpeg asynchronously
      debugPrint("Starting FFmpeg video encoding: ${width}x$height @ ${fps}fps");
      _ffmpegSession = FFmpegKit.execute(ffmpegCommand).then((session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint("FFmpeg video encoding completed successfully.");
        } else {
          final logs = await session.getLogsAsString();
          debugPrint("FFmpeg video encoding failed with rc=$returnCode.\nLogs: $logs");
        }
      });
    } catch (e) {
      debugPrint("Encoding error: $e");
      await stopVideoEncoding();
      rethrow;
    }
  }

  /// Stops writing to the pipe, closes it, and waits for FFmpeg to finish.
  Future<void> stopVideoEncoding() async {
    debugPrint("Cancelling frame subscription...");
    await _frameSubscription?.cancel();
    _frameSubscription = null;

    debugPrint("Closing video pipe sink...");
    try {
      await _videoPipeSink?.flush();
      await _videoPipeSink?.close();
    } catch (e) {
      debugPrint("Pipe close warning (non-fatal): $e");
    }
    _videoPipeSink = null;
    debugPrint("Video pipe sink closed.");

    if (_ffmpegSession != null) {
      debugPrint("Waiting for FFmpeg video session to finish...");
      await _ffmpegSession;
      _ffmpegSession = null;
      debugPrint("FFmpeg video session finished.");
    }

    if (_videoPipePath != null) {
      _videoPipePath = null;
    }
  }

  /// Combines the temporary video and audio files into the final output.
  Future<void> combineVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    final String ffmpegCommand =
        '-i $videoPath -i $audioPath -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -y $outputPath';
    debugPrint("Starting FFmpeg muxing...");

    final session = await FFmpegKit.execute(ffmpegCommand);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint("FFmpeg muxing completed successfully.");
    } else {
      final logs = await session.getLogsAsString();
      debugPrint("FFmpeg muxing failed with rc=$returnCode.\nLogs: $logs");
    }
  }
}
