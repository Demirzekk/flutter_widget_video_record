import 'package:flutter/widgets.dart';
import '../controller/widget_recorder_controller.dart';

class WidgetRecorder extends StatelessWidget {
  final Widget child;
  final WidgetRecorderController controller;

  const WidgetRecorder({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: controller.boundaryKey,
      child: child,
    );
  }
}
