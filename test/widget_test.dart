import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('TvApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TvApp());
    expect(find.byType(TvApp), findsOneWidget);
  });
}
