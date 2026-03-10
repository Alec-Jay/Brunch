import 'package:flutter_test/flutter_test.dart';
import 'package:brunch/main.dart';

void main() {
  testWidgets('Brunch app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BrunchApp());
    expect(find.text('Brunch'), findsWidgets);
  });
}
