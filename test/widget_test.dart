import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:money_manager/main.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/providers/auth_provider.dart';

void main() {
  testWidgets('App renders and shows auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
          ChangeNotifierProvider(create: (_) => AppProvider()),
        ],
        child: const MoneyManagerApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
