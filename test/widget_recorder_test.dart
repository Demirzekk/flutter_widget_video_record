import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_widget_video_record/flutter_widget_video_record.dart';

void main() {
  group('WidgetRecorderController Tests', () {
    test('Başlangıç değerleri (Initial State) doğru atanmalı', () {
      final controller = WidgetRecorderController(fps: 60, pixelRatio: 2.5);
      
      expect(controller.fps, 60);
      expect(controller.pixelRatio, 2.5);
      expect(controller.isRecording, isFalse);
    });

    test('Kayıt başlamadan stop() çağrıldığında null dönmeli', () async {
      final controller = WidgetRecorderController();
      
      final result = await controller.stop();
      expect(result, isNull);
    });
  });

  group('WidgetRecorder UI Tests', () {
    testWidgets('WidgetRecorder, child widgetı RepaintBoundary ile sarmalamalı', (WidgetTester tester) async {
      final controller = WidgetRecorderController();
      
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WidgetRecorder(
            controller: controller,
            child: const Text('Test Child Widget'),
          ),
        ),
      );

      // Child widget'ın render edildiğini doğrula
      expect(find.text('Test Child Widget'), findsOneWidget);

      // RepaintBoundary'nin eklendiğini doğrula
      final boundaryFinder = find.byType(RepaintBoundary);
      expect(boundaryFinder, findsOneWidget);
      
      // RepaintBoundary'nin key değerinin Controller'daki key ile aynı olduğunu doğrula
      final RepaintBoundary boundary = tester.widget(boundaryFinder);
      expect(boundary.key, equals(controller.boundaryKey));
    });
  });
}
