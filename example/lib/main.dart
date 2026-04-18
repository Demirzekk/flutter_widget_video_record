import 'package:flutter/material.dart';
import 'package:flutter_widget_video_record/flutter_widget_video_record.dart';
import 'video_list_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Widget Video Record Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage>
    with SingleTickerProviderStateMixin {
  late WidgetRecorderController _controller;
  late final AnimationController _animController;
  String? _videoPath;
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    // Simple rotation animation to show movement in video
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isControllerInitialized) {
      // Cap pixel ratio at 1.5 for good balance of quality vs performance.
      // Full device ratio (2.75-3.5 on modern phones) produces enormous frames
      // that overwhelm the GPU readback and cause severe jank.
      final deviceRatio = MediaQuery.of(context).devicePixelRatio;
      final cappedRatio = deviceRatio.clamp(1.0, 1.5);
      _controller = WidgetRecorderController(fps: 30, pixelRatio: cappedRatio);
      _isControllerInitialized = true;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleRecording() async {
    if (_controller.isRecording) {
      final path = await _controller.stop();
      setState(() {
        _videoPath = path;
      });
      if (mounted && path != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Video saved to: $path')));
      }
    } else {
      final success = await _controller.start();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ses kayıt izni verilmedi! Video kaydedilemez.'),
          ),
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Modern dark slate
      appBar: AppBar(
        title: const Text(
          'PRO Widget Recorder',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoListPage()),
              );
            },
            icon: const Icon(Icons.video_library, color: Colors.white),
            tooltip: 'Gallery',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. THE RECORDING TARGET (The Full Screen Content)
          WidgetRecorder(
            controller: _controller,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      // Animated Header
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _animController.value * 2 * 3.14159,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(
                                  colors: [
                                    Colors.cyan,
                                    Colors.purple,
                                    Colors.yellow,
                                    Colors.cyan,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyan.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const FlutterLogo(size: 80),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        "Dynamic Dashboard",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Capturing every pixel in 60 FPS",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Interactive Grid
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                              ),
                          itemCount: 4,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    [
                                      Icons.bolt,
                                      Icons.speed,
                                      Icons.security,
                                      Icons.auto_awesome,
                                    ][index],
                                    color: [
                                      Colors.yellow,
                                      Colors.redAccent,
                                      Colors.greenAccent,
                                      Colors.purpleAccent,
                                    ][index],
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    [
                                      "Fast",
                                      "Smooth",
                                      "Secure",
                                      "Smart",
                                    ][index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Scrolling Content Area
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: List.generate(
                            3,
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blueGrey,
                                    child: Text("${i + 1}"),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 12,
                                          width: 100,
                                          color: Colors.white24,
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          height: 8,
                                          width: double.infinity,
                                          color: Colors.white12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. OVERLAY CONTROLS (Not Recorded)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.3),
                  BlendMode.darken,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatusIndicator(),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          _controller.isRecording
                              ? 'RECORDING LIVE...'
                              : 'Ready to record',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FloatingActionButton.extended(
                        onPressed: _toggleRecording,
                        backgroundColor: _controller.isRecording
                            ? Colors.redAccent
                            : Colors.cyanAccent,
                        icon: Icon(
                          _controller.isRecording
                              ? Icons.stop_rounded
                              : Icons.fiber_manual_record_rounded,
                          color: Colors.black,
                        ),
                        label: Text(
                          _controller.isRecording ? 'STOP' : 'START',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return _controller.isRecording
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(
                    alpha: 0.3 + (0.7 * (1.0 - (value - 0.5).abs() * 2)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 10 * value,
                      spreadRadius: 2 * value,
                    ),
                  ],
                ),
              );
            },
            onEnd: () => setState(() {}),
          )
        : Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.greenAccent,
            ),
          );
  }
}
