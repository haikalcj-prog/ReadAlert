import 'package:flutter_test/flutter_test.dart';
import 'package:readalert/main.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ReadAlertApp());

    expect(find.text('ReadAlert Initialized 🔥'), findsOneWidget);
  });
}
