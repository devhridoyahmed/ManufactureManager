import 'package:flutter_test/flutter_test.dart';

import 'package:manufacture_business_manager/main.dart';

void main() {
  testWidgets(
    'Manufacturing Manager app loads',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ManufacturingManagerApp(),
      );

      expect(
        find.text('Manufacturing Manager'),
        findsOneWidget,
      );

      expect(
        find.text('Business setup completed'),
        findsOneWidget,
      );

      expect(
        find.text('Business and default units are ready.'),
        findsOneWidget,
      );
    },
  );
}