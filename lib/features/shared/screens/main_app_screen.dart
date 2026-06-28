import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/features/dashboard/screens/dashboard_screen.dart';
import 'package:money_manager/features/expenses/screens/expenses_screen.dart';
import 'package:money_manager/features/income/screens/income_screen.dart';
import 'package:money_manager/features/sync/screens/sync_screen.dart';
import 'package:money_manager/features/shared/screens/settings_screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    ExpensesScreen(),
    IncomeScreen(),
    SyncScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[appProvider.currentTabIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.surfaceVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: appProvider.currentTabIndex,
          onTap: (index) => appProvider.setTabIndex(index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Expenses'),
            BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Income'),
            BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'Sync'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
