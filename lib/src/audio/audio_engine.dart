import 'package:record/record.dart';

class AudioEngine {
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> startRecording(String path) async {
    // Check and request permission
    if (await _audioRecorder.hasPermission()) {
      // Start recording
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000),
        path: path,
      );
    } else {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    return path; // Returns the recorded file path
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
