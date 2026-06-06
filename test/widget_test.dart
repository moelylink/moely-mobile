import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/views/video_splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock the video player method channel to avoid MissingPluginException
    const MethodChannel('flutter.io/videoPlayer')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'init') {
        return null;
      }
      if (methodCall.method == 'create') {
        return {'textureId': 1};
      }
      return null;
    });
  });

  testWidgets('App initialization and tab smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MoelyApp());

    // Verify that the VideoSplashScreen is rendered.
    expect(find.byType(VideoSplashScreen), findsOneWidget);
  });
}
