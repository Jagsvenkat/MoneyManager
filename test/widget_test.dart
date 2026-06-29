import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:money_manager/main.dart';

void main() {
  testWidgets('App renders and shows auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyManagerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
