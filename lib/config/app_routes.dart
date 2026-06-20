import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/expenses/screens/expenses_screen.dart';
import '../features/categories/screens/categories_screen.dart';
import '../features/shared/screens/main_app_screen.dart';
import '../features/shared/screens/settings_screen.dart';

/// Route paths for the application
class AppRoutes {
  // Auth routes
  static const String login = '/login';
  static const String register = '/register';

  // Main app routes
  static const String home = '/';
  static const String dashboard = '/dashboard';
  static const String expenses = '/expenses';
  static const String categories = '/categories';
  static const String settings = '/settings';
}

/// GoRouter configuration for the Money Manager app
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: <RouteBase>[
    // Auth Routes
    GoRoute(
      path: AppRoutes.login,
      builder: (BuildContext context, GoRouterState state) =>
          const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (BuildContext context, GoRouterState state) =>
          const RegisterScreen(),
    ),

    // Main App Routes
    GoRoute(
      path: AppRoutes.home,
      builder: (BuildContext context, GoRouterState state) =>
          const MainAppScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'dashboard',
          builder: (BuildContext context, GoRouterState state) =>
              const DashboardScreen(),
        ),
        GoRoute(
          path: 'expenses',
          builder: (BuildContext context, GoRouterState state) =>
              const ExpensesScreen(),
        ),
        GoRoute(
          path: 'categories',
          builder: (BuildContext context, GoRouterState state) =>
              const CategoriesScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
