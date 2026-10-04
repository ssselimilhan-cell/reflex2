import 'package:flutter_test/flutter_test.dart';

import 'package:stres_kart/main.dart';

void main() {
  testWidgets('Stres Kart uygulaması açılıyor', (WidgetTester tester) async {
    await tester.pumpWidget(const StresApp());
    await tester.pump();
  });
}
