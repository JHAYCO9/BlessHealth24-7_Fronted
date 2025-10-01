import 'package:bless_health24/componentes/shared/info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('InfoRow', () {
    testWidgets('renders label and value with defaults', (tester) async {
      await _pump(
        tester,
        const InfoRow(label: 'Nombre', value: 'Juan Pérez'),
      );

      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsOneWidget);
    });

    testWidgets('shows dash when value is empty', (tester) async {
      await _pump(
        tester,
        const InfoRow(label: 'Correo', value: ''),
      );

      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('respects showColon flag and alignment', (tester) async {
      await _pump(
        tester,
        const InfoRow(
          label: 'Documento',
          value: '123',
          showColon: true,
          alignEnd: false,
          labelWidth: 80,
        ),
      );

      expect(find.text('Documento:'), findsOneWidget);
      final text = tester.widget<Text>(find.text('123'));
      expect(text.textAlign, TextAlign.left);
    });
  });
}
