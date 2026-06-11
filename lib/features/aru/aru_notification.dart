// =============================================================================
// ARU Notification Service - Foreground notification for scheduled deployments
// =============================================================================

import 'dart:io';
import 'dart:ui';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void aruTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_AruTaskHandler());
}

class _AruTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[AruTaskHandler] onStart');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[AruTaskHandler] onDestroy');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.sendDataToMain({'action': 'aruStop'});
    } else if (id == 'open') {
      FlutterForegroundTask.launchApp();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

class AruNotificationService {
  static String _notificationTitle = '';
  static String _stopButtonText = '';
  static String _openButtonText = '';
  static const Duration _startRetryDelay = Duration(minutes: 1);
  bool _running = false;
  bool _starting = false;
  DateTime? _nextStartAttempt;

  bool get isRunning => _running;
  static String get notificationTitle => _notificationTitle;

  static Future<void> init() async {
    final l10n = await _loadAppLocalizations();
    _notificationTitle = l10n.aruNotificationTitle;
    _stopButtonText = l10n.notificationStop;
    _openButtonText = l10n.notificationOpen;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'birdnet_aru_fg',
        channelName: l10n.aruNotificationChannelName,
        channelDescription: l10n.aruNotificationChannelDescription,
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission == NotificationPermission.granted) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  Future<void> start({required String title, required String text}) async {
    if (!Platform.isAndroid) return;
    if (_running || _starting) return;

    final now = DateTime.now();
    final nextAttempt = _nextStartAttempt;
    if (nextAttempt != null && now.isBefore(nextAttempt)) {
      return;
    }

    _starting = true;
    try {
      await init();

      final granted = await ensurePermission();
      if (!granted) {
        debugPrint(
          '[AruNotification] permission not granted - attempting startService',
        );
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 512,
        notificationTitle: title,
        notificationText: text,
        notificationIcon: const NotificationIcon(
          metaDataName: 'com.birdnet.live.notification_icon',
        ),
        notificationButtons: [
          NotificationButton(id: 'stop', text: _stopButtonText),
          NotificationButton(id: 'open', text: _openButtonText),
        ],
        callback: aruTaskCallback,
      );
      if (result is ServiceRequestSuccess) {
        _running = true;
        _nextStartAttempt = null;
        debugPrint('[AruNotification] started');
      } else {
        _running = false;
        _nextStartAttempt = now.add(_startRetryDelay);
        debugPrint(
          '[AruNotification] startService failed: $result. '
          'Retrying in ${_startRetryDelay.inSeconds}s.',
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> update({required String title, required String text}) async {
    if (!_running) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.birdnet.live.notification_icon',
      ),
    );
  }

  Future<void> stop() async {
    if (!_running) return;
    await FlutterForegroundTask.stopService();
    _running = false;
    _nextStartAttempt = null;
    debugPrint('[AruNotification] stopped');
  }
}

Future<AppLocalizations> _loadAppLocalizations() async {
  final deviceLocale = PlatformDispatcher.instance.locale;
  final supportedLocale = AppLocalizations.supportedLocales.firstWhere(
    (locale) => locale.languageCode == deviceLocale.languageCode,
    orElse: () => const Locale('en'),
  );
  return AppLocalizations.delegate.load(supportedLocale);
}
