import 'package:flutter_test/flutter_test.dart';
import 'package:readalert/main.dart';

void main() {
  testWidgets('App shows the login screen when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ReadAlertApp(authStateChanges: Stream.value(null)));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
