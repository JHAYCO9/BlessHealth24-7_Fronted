import 'package:bless_health24/componentes/shared/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('ErrorView', () {
    testWidgets('renders message and icon without retry button', (
      tester,
    ) async {
      const message = 'Algo salió mal';

      await _pump(tester, const ErrorView(message: message));

      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('calls onRetry when the button is pressed', (tester) async {
      var tapped = false;
      const message = 'Error con reintento';

      await _pump(
        tester,
        ErrorView(
          message: message,
          onRetry: () {
            tapped = true;
          },
          retryLabel: 'Intentar de nuevo',
        ),
      );

      final buttonFinder = find.text('Intentar de nuevo');
      expect(buttonFinder, findsOneWidget);
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('EmptyView', () {
    testWidgets('shows informative message and default icon', (tester) async {
      const message = 'Sin resultados';

      await _pump(tester, const EmptyView(message: message));

      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });
  });
}
