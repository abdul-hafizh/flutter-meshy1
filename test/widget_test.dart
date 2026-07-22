import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_meshy1/main.dart';

void main() {
  testWidgets('Snapy app shows Beranda with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const SnapyApp());

    expect(find.text('Creator'), findsOneWidget);
    expect(find.text('Apa yang mau kamu ciptakan?'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);

    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();

    expect(find.text('Marketplace'), findsOneWidget);
  });
}
