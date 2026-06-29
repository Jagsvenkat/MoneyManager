import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:money_manager/features/auth/screens/login_screen.dart';
import 'package:money_manager/features/auth/screens/register_screen.dart';
import 'package:money_manager/features/shared/screens/main_app_screen.dart';
import 'package:money_manager/features/categories/screens/categories_screen.dart';
import 'package:money_manager/providers/auth_provider.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String categories = '/categories';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final isAuth = auth.isAuthenticated;
    final isOnAuthPage = state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;

    if (isAuth && isOnAuthPage) return AppRoutes.home;
    if (!isAuth && !isOnAuthPage) return AppRoutes.login;
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.login,
      builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (BuildContext context, GoRouterState state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (BuildContext context, GoRouterState state) => const MainAppScreen(),
    ),
    GoRoute(
      path: AppRoutes.categories,
      builder: (BuildContext context, GoRouterState state) {
        final type = state.uri.queryParameters['type'] ?? 'expense';
        return CategoriesScreen(type: type);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
