import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/aru/aru_notification.dart';
import 'features/aru/aru_notification_route.dart';
import 'shared/providers/app_providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Resolve the UI locale from the platform/app preference list.
///
/// Flutter's generated locale list is alphabetized, so relying on the default
/// fallback can land unsupported languages on Czech because `cs` is first.
/// Prefer an exact language match from the user's locale list, otherwise fall
/// back to English explicitly.
Locale resolveAppLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList();
  for (final preferred in preferredLocales ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == preferred.languageCode) return candidate;
    }
  }

  return supported.firstWhere(
    (locale) => locale.languageCode == 'en',
    orElse: () => supported.first,
  );
}

/// Root application widget.
///
/// Configures theme, localization, and the initial route based on
/// whether onboarding and policy acceptance have been completed.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final useDynamicColor = ref.watch(dynamicColorProvider);
    final useHighContrastTheme = ref.watch(highContrastThemeProvider);
    final locale = ref.watch(localeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Use the platform's dynamic palette when the user has opted in
        // and the OS provides one. Otherwise fall back to the brand theme.
        final ThemeData lightTheme;
        final ThemeData darkTheme;

        if (useHighContrastTheme) {
          lightTheme = AppTheme.highContrastLight();
          darkTheme = AppTheme.highContrastDark();
        } else if (useDynamicColor &&
            lightDynamic != null &&
            darkDynamic != null) {
          lightTheme = AppTheme.fromColorScheme(lightDynamic.harmonized());
          darkTheme = AppTheme.fromColorScheme(darkDynamic.harmonized());
        } else {
          lightTheme = AppTheme.light();
          darkTheme = AppTheme.dark();
        }

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,

          // Theme
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,

          // Localization
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppLocale,
          localeResolutionCallback:
              (locale, supportedLocales) => resolveAppLocale(
                locale == null ? null : <Locale>[locale],
                supportedLocales,
              ),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case AruNotificationService.openRoute:
                return MaterialPageRoute<void>(
                  builder:
                      (_) => const AruNotificationRoute(requestStop: false),
                  settings: settings,
                );
              case AruNotificationService.stopRoute:
                return MaterialPageRoute<void>(
                  builder: (_) => const AruNotificationRoute(requestStop: true),
                  settings: settings,
                );
            }
            return null;
          },

          // Initial screen based on app state
          home: const _AruNotificationActionListener(child: _AppGate()),
        );
      },
    );
  }
}

class _AruNotificationActionListener extends ConsumerStatefulWidget {
  const _AruNotificationActionListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_AruNotificationActionListener> createState() =>
      _AruNotificationActionListenerState();
}

class _AruNotificationActionListenerState
    extends ConsumerState<_AruNotificationActionListener> {
  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    AruNotificationService.setNativeActionHandler(_onNativeAction);
    unawaited(_takePendingNativeAction());
  }

  @override
  void dispose() {
    AruNotificationService.setNativeActionHandler(null);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _takePendingNativeAction() async {
    final action = await AruNotificationService.takePendingNativeAction();
    if (!mounted || action == null) return;
    _handleAruAction(action);
  }

  void _onNativeAction(String action) {
    if (!mounted) return;
    _handleAruAction(action);
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final action = data['action'];
    if (action is String) {
      _handleAruAction(action);
    }
  }

  void _handleAruAction(String action) {
    if (action == 'aruOpen') {
      _openAruRoute(requestStop: false);
    } else if (action == 'aruStop') {
      _openAruRoute(requestStop: true);
    }
  }

  void _openAruRoute({required bool requestStop}) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AruNotificationRoute(requestStop: requestStop),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Gate widget that routes to onboarding or the home screen.
class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final termsAccepted = ref.watch(termsAcceptedProvider);

    // The onboarding flow now also captures acceptable-use acceptance, so a
    // completed onboarding implies accepted policy. We still gate on both
    // independently so a future settings reset of either flag re-shows the
    // onboarding flow.
    if (!onboardingComplete || !termsAccepted) {
      return const OnboardingScreen();
    }

    return const HomeScreen();
  }
}
