import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/features/auth/screens/login_screen.dart';
import 'package:money_manager/features/auth/screens/register_screen.dart';
import 'package:money_manager/features/auth/screens/splash_screen.dart';
import 'package:money_manager/features/shared/screens/main_app_screen.dart';
import 'package:money_manager/features/categories/screens/categories_screen.dart';
import 'package:money_manager/features/recurring/screens/recurring_screen.dart';
import 'package:money_manager/providers/auth_provider.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String categories = '/categories';
  static const String recurring = '/recurring';
}

GoRouter createAppRouter({required AuthProvider authProvider}) {
  return GoRouter(
    refreshListenable: authProvider,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final auth = authProvider;
      if (auth.isInitializing) return null;
      final isAuth = auth.isAuthenticated;
      final current = state.matchedLocation;
      if (isAuth && (current == AppRoutes.splash || current == AppRoutes.login || current == AppRoutes.register)) {
        return AppRoutes.home;
      }
      if (!isAuth && current != AppRoutes.login && current != AppRoutes.register) {
        return AppRoutes.login;
      }
      if (isAuth && current == AppRoutes.splash) return AppRoutes.home;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.recurring,
        builder: (BuildContext context, GoRouterState state) => const RecurringScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
}
