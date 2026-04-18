import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'video_player_page.dart';

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  List<File> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    final tempDir = await getTemporaryDirectory();
    final files = tempDir.listSync();
    
    final videos = files
        .where((file) => file is File && file.path.endsWith('.mp4'))
        .cast<File>()
        .toList();
        
    // Sort by newest first
    videos.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {
      _videos = videos;
      _isLoading = false;
    });
  }

  void _deleteVideo(File file) {
    file.deleteSync();
    _loadVideos();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorded Videos'),
        actions: [
          IconButton(
            onPressed: _loadVideos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text('No videos recorded yet'))
              : ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    final fileName = video.path.split(Platform.pathSeparator).last;
                    final size = (video.lengthSync() / (1024 * 1024)).toStringAsFixed(2);

                    return ListTile(
                      leading: const Icon(Icons.video_file, color: Colors.blue),
                      title: Text(fileName),
                      subtitle: Text('$size MB'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteVideo(video),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerPage(videoFile: video),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
