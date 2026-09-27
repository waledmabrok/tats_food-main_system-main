import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_casher/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders without overflow and supports typing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.first, 'owner');
    await tester.pumpAndSettle();

    expect(find.text('owner'), findsOneWidget);

    await tester.enterText(textFields.last, 'owner1234');
    await tester.pumpAndSettle();

    // Check quick buttons exist
    expect(find.text('👤 المالك (Owner)'), findsOneWidget);
    expect(find.text('💵 الكاشير (Cashier)'), findsOneWidget);
  });
}
