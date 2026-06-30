import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:money_manager/main.dart';
import 'package:money_manager/config/app_routes.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/providers/auth_provider.dart';

void main() {
  testWidgets('App renders and shows auth screen', (WidgetTester tester) async {
    final authProvider = AuthProvider()..initialize();
    final appRouter = createAppRouter(authProvider: authProvider);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => AppProvider()),
        ],
        child: MoneyManagerApp(routerConfig: appRouter),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
