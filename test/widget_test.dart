import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/views/home_screen.dart';

void main() {
  testWidgets('App initialization and tab smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MoelyApp());

    // Verify that the HomeScreen is rendered.
    expect(find.byType(HomeScreen), findsOneWidget);
    
    // Verify that the "最新" (Latest) tab indicator is present.
    expect(find.text('最新'), findsOneWidget);
    
    // Verify that the "随机" (Random) tab indicator is present.
    expect(find.text('随机'), findsOneWidget);
  });
}
