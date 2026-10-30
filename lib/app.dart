import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/theme/app_theme.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/home/presentation/home_shell.dart';
import 'package:gsu_fit/features/profile/application/profile_providers.dart';
import 'package:gsu_fit/features/profile/presentation/onboarding_screen.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';

class GsuFitApp extends ConsumerWidget {
  const GsuFitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const RootGate(),
    );
  }
}

/// Shows onboarding until a profile exists, then the main app.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return profile.when(
      data: (value) => value == null ? const OnboardingScreen() : const HomeShell(),
      loading: () => const SplashView(),
      error: (error, stackTrace) => Scaffold(
        body: ErrorView(
          message: context.l10n.errorLoadFailed,
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(context.l10n.appTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Shown when the database cannot be opened; there is nothing else to run.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: EmptyState(
            icon: Icons.storage,
            title: context.l10n.errorStartupTitle,
            message: context.l10n.errorStartupMessage,
          ),
        ),
      ),
    );
  }
}
