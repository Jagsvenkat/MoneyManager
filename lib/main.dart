import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'config/app_colors.dart';
import 'config/app_routes.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final authProvider = AuthProvider()..initialize();
  final appRouter = createAppRouter(authProvider: authProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MoneyManagerApp(routerConfig: appRouter),
    ),
  );
}

class MoneyManagerApp extends StatefulWidget {
  final GoRouter routerConfig;

  const MoneyManagerApp({super.key, required this.routerConfig});

  @override
  State<MoneyManagerApp> createState() => _MoneyManagerAppState();
}

class _MoneyManagerAppState extends State<MoneyManagerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadTheme();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return MaterialApp.router(
            routerConfig: widget.routerConfig,
            debugShowCheckedModeBanner: false,
            title: 'Money Manager',
            themeMode: appProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColorsLight.background,
              colorScheme: const ColorScheme.light(
                primary: AppColorsLight.primary,
                onPrimary: AppColorsLight.onPrimary,
                primaryContainer: AppColorsLight.primaryContainer,
                onPrimaryContainer: AppColorsLight.onPrimaryContainer,
                secondary: AppColorsLight.secondary,
                onSecondary: AppColorsLight.onSecondary,
                secondaryContainer: AppColorsLight.secondaryContainer,
                onSecondaryContainer: AppColorsLight.onSecondaryContainer,
                tertiary: AppColorsLight.tertiary,
                onTertiary: AppColorsLight.onTertiary,
                tertiaryContainer: AppColorsLight.tertiaryContainer,
                onTertiaryContainer: AppColorsLight.onTertiaryContainer,
                error: AppColorsLight.error,
                onError: AppColorsLight.onError,
                errorContainer: AppColorsLight.errorContainer,
                onErrorContainer: AppColorsLight.onErrorContainer,
                surface: AppColorsLight.surface,
                onSurface: AppColorsLight.onSurface,
                surfaceContainerHighest: AppColorsLight.surfaceVariant,
                onSurfaceVariant: AppColorsLight.onSurfaceVariant,
                outline: AppColorsLight.outline,
                outlineVariant: AppColorsLight.outlineVariant,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColorsLight.background,
                foregroundColor: AppColorsLight.onBackground,
                elevation: 0,
                centerTitle: true,
              ),
              cardTheme: CardThemeData(
                color: AppColorsLight.surfaceVariant,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: AppColorsLight.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColorsLight.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColorsLight.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: AppColorsLight.primary,
                foregroundColor: AppColorsLight.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: AppColorsLight.surface,
                indicatorColor: AppColorsLight.primaryContainer.withAlpha(80),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColorsLight.primary);
                  }
                  return const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColorsLight.onSurfaceVariant);
                }),
              ),
              chipTheme: ChipThemeData(
                backgroundColor: AppColorsLight.surfaceVariant,
                selectedColor: AppColorsLight.primaryContainer,
                labelStyle: const TextStyle(color: AppColorsLight.onSurface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              segmentedButtonTheme: SegmentedButtonThemeData(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColorsLight.primaryContainer;
                    return AppColorsLight.surfaceVariant;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColorsLight.onPrimaryContainer;
                    return AppColorsLight.onSurfaceVariant;
                  }),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.background,
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: AppColors.onPrimary,
                primaryContainer: AppColors.primaryContainer,
                onPrimaryContainer: AppColors.onPrimaryContainer,
                secondary: AppColors.secondary,
                onSecondary: AppColors.onSecondary,
                secondaryContainer: AppColors.secondaryContainer,
                onSecondaryContainer: AppColors.onSecondaryContainer,
                tertiary: AppColors.tertiary,
                onTertiary: AppColors.onTertiary,
                tertiaryContainer: AppColors.tertiaryContainer,
                onTertiaryContainer: AppColors.onTertiaryContainer,
                error: AppColors.error,
                onError: AppColors.onError,
                errorContainer: AppColors.errorContainer,
                onErrorContainer: AppColors.onErrorContainer,
                surface: AppColors.surface,
                onSurface: AppColors.onSurface,
                surfaceContainerHighest: AppColors.surfaceVariant,
                onSurfaceVariant: AppColors.onSurfaceVariant,
                outline: AppColors.outline,
                outlineVariant: AppColors.outlineVariant,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.onBackground,
                elevation: 0,
                centerTitle: true,
              ),
              cardTheme: CardThemeData(
                color: AppColors.surfaceVariant,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.primaryContainer.withAlpha(80),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary);
                  }
                  return const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant);
                }),
              ),
              chipTheme: ChipThemeData(
                backgroundColor: AppColors.surfaceVariant,
                selectedColor: AppColors.primaryContainer,
                labelStyle: const TextStyle(color: AppColors.onSurface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              segmentedButtonTheme: SegmentedButtonThemeData(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.primaryContainer;
                    return AppColors.surfaceVariant;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.onPrimaryContainer;
                    return AppColors.onSurfaceVariant;
                  }),
                ),
              ),
            ),
          );
        },
    );
  }
}
