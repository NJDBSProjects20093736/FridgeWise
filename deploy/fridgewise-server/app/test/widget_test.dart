import 'package:flutter_test/flutter_test.dart';
import 'package:fridgewise_ai/main.dart';

void main() {
  testWidgets('FridgeWise app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const FridgeWiseApp(),
    );
    expect(find.textContaining('FridgeWise'), findsWidgets);
  });
}
