import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test renders material app', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('TAN RSS Mobile'),
        ),
      ),
    );

    expect(find.text('TAN RSS Mobile'), findsOneWidget);
  });
}
