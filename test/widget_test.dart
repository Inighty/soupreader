import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/main.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SoupReaderApp());

    // Verify that the app shows the bookshelf view
    expect(find.text('书架'), findsOneWidget);
  });
}
