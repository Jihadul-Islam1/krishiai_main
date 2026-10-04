import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:krishiai/main.dart';

void main() {
  testWidgets('KrishiAI pumps without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KrishiAI()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
