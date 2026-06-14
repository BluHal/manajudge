// Smoke test for the Phase 0 placeholder app.

import 'package:flutter_test/flutter_test.dart';

import 'package:manajudge/main.dart';

void main() {
  testWidgets('Placeholder renders the manajudge surfaces', (tester) async {
    await tester.pumpWidget(const ManajudgeApp());

    expect(find.text('⚖️ manajudge'), findsOneWidget);
    expect(find.text('Companion'), findsOneWidget);
    expect(find.text('Judge'), findsOneWidget);
    expect(find.text('Card Search'), findsOneWidget);
  });
}
