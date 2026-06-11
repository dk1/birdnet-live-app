import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:birdnet_live/shared/widgets/app_help_bottom_sheet.dart';
import 'package:birdnet_live/shared/widgets/stat_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/providers/settings_providers.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../audio/ring_buffer.dart';
import '../explore/explore_providers.dart';
import '../history/session_library_screen.dart';
import '../history/session_review_screen.dart';
import '../live/live_controller.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../live/widgets/detection_list_widget.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import 'aru_controller.dart';
import 'aru_notification.dart';
import 'aru_providers.dart';
import 'aru_schedule.dart';

class AruActiveScreen extends ConsumerStatefulWidget {
  const AruActiveScreen({super.key});

  @override
  ConsumerState<AruActiveScreen> createState() => _AruActiveScreenState();
}

class _AruActiveScreenState extends ConsumerState<AruActiveScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final TabController _tabController;
  final AruNotificationService _notificationService = AruNotificationService();
  final Battery _battery = Battery();
  bool _stopping = false;
  bool _tickBusy = false;
  bool _inferenceStarting = false;
  bool _aruInferenceActive = false;
  DateTime? _lastBatteryCheck;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    ref.read(liveControllerProvider).onStateChanged = _onInferenceStateChanged;
    FlutterForegroundTask.addTaskDataCallback(_onNotificationData);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _tick();
      if (!mounted) return;
      await _syncNotification();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    final liveController = ref.read(liveControllerProvider);
    if (liveController.onStateChanged == _onInferenceStateChanged) {
      liveController.onStateChanged = null;
    }
    _tabController.dispose();
    FlutterForegroundTask.removeTaskDataCallback(_onNotificationData);
    super.dispose();
  }

  void _onInferenceStateChanged() {
    if (!mounted) return;
    _syncDetectionsFromInference();
  }

  Future<void> _syncDetectionsFromInference() async {
    final controller = ref.read(aruControllerProvider);
    final liveController = ref.read(liveControllerProvider);
    await controller.syncDetections(liveController.sessionDetections);
    if (!mounted) return;
    ref.read(aruSessionProvider.notifier).state = controller.session;
    setState(() {});
  }

  void _onNotificationData(Object data) {
    if (data is Map && data['action'] == 'aruStop') {
      _confirmStop();
    }
  }

  Future<void> _tick() async {
    if (!mounted || _stopping || _tickBusy) return;
    _tickBusy = true;
    try {
      final controller = ref.read(aruControllerProvider);
      final session = controller.session;
      if (session == null || controller.state == AruControllerState.completed) {
        return;
      }
      if (controller.state == AruControllerState.recording &&
          _scheduleSnapshot(session)?.currentWindow == null) {
        await _stopInference();
      }
      if (await _stopIfBatteryBelowThreshold(controller)) {
        return;
      }
      await controller.evaluate();
      if (!mounted) return;
      ref.read(aruStateProvider.notifier).state = controller.state;
      ref.read(aruSessionProvider.notifier).state = controller.session;
      await _syncInferenceSession(controller.state, controller.session);
      await _syncNotification();
    } finally {
      _tickBusy = false;
    }
  }

  Future<void> _syncInferenceSession(
    AruControllerState state,
    LiveSession? session,
  ) async {
    if (session == null) return;
    if (state == AruControllerState.recording) {
      await _startInference(session);
    } else {
      await _stopInference();
    }
  }

  Future<void> _startInference(LiveSession session) async {
    if (_aruInferenceActive || _inferenceStarting) return;
    _inferenceStarting = true;
    try {
      final controller = ref.read(liveControllerProvider);
      if (controller.state == LiveState.idle) {
        await controller.loadModel();
      }
      if (controller.state != LiveState.ready) return;

      await controller.startSession(
        windowDuration: session.settings.windowDuration,
        inferenceRate: session.settings.inferenceRate,
        confidenceThreshold: session.settings.confidenceThreshold,
        speciesFilterMode: session.settings.speciesFilterMode,
        recordingMode: RecordingMode.off,
        geoScores: await ref.read(geoScoresProvider.future),
        geoThreshold: ref.read(geoThresholdProvider),
        geoModelSpeciesNames: await ref.read(
          geoModelSpeciesNamesProvider.future,
        ),
        poolingWindows: session.settings.poolingWindows,
        poolingMode: session.settings.poolingMode ?? 'lme',
        sensitivity: session.settings.sensitivity ?? 1.0,
        gainLinear: session.settings.gainLinear,
        highPassHz: session.settings.highPassHz,
        latitude: session.latitude,
        longitude: session.longitude,
      );
      _aruInferenceActive = controller.state == LiveState.active;
      _onInferenceStateChanged();
    } finally {
      _inferenceStarting = false;
    }
  }

  Future<void> _stopInference() async {
    if (!_aruInferenceActive) return;
    final controller = ref.read(liveControllerProvider);
    await _syncDetectionsFromInference();
    if (controller.state == LiveState.active ||
        controller.state == LiveState.paused) {
      await controller.finalizeSession();
    }
    _aruInferenceActive = false;
  }

  Future<void> _confirmStop() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.aruStopConfirmTitle),
            content: Text(l10n.aruStopConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(AppIcons.stopRounded),
                label: Text(l10n.aruStopDeployment),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await _stopDeployment();
    }
  }

  Future<void> _stopDeployment() async {
    if (_stopping || !mounted) return;
    setState(() => _stopping = true);
    final reviewSession = await _finishDeployment(
      reason: SessionStopReason.manual,
    );
    if (!mounted) return;
    setState(() => _stopping = false);
    _openReview(reviewSession);
  }

  Future<LiveSession?> _finishDeployment({
    required SessionStopReason reason,
    num? reasonValue,
  }) async {
    final controller = ref.read(aruControllerProvider);
    await _stopInference();
    await controller.stop(reason: reason, reasonValue: reasonValue);
    if (!mounted) return controller.reviewSession;
    ref.read(aruStateProvider.notifier).state = controller.state;
    ref.read(aruSessionProvider.notifier).state = controller.session;
    await _notificationService.stop();
    ref.invalidate(sessionListProvider);
    return controller.reviewSession;
  }

  void _openReview(LiveSession? session) {
    if (!mounted || session == null) {
      Navigator.of(context).pop();
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (a, b, c) => const SessionLibraryScreen(),
      ),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SessionReviewScreen(session: session),
      ),
    );
  }

  Future<bool> _stopIfBatteryBelowThreshold(AruController controller) async {
    final threshold = controller.session?.aruMetadata?.lowBatteryStopPercent;
    if (threshold == null || threshold <= 0) return false;

    final now = DateTime.now();
    if (_lastBatteryCheck != null &&
        now.difference(_lastBatteryCheck!) < const Duration(minutes: 1)) {
      return false;
    }
    _lastBatteryCheck = now;

    try {
      final level = await _battery.batteryLevel;
      if (level > threshold) return false;

      if (mounted) setState(() => _stopping = true);
      final reviewSession = await _finishDeployment(
        reason: SessionStopReason.lowBattery,
        reasonValue: level,
      );
      if (!mounted) return true;
      setState(() => _stopping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.sessionAutoStopLowBattery(level),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      _openReview(reviewSession);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncNotification() async {
    final session = ref.read(aruSessionProvider);
    final state = ref.read(aruStateProvider);
    if (session == null || state == AruControllerState.completed) {
      await _notificationService.stop();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final text = _notificationText(l10n, state, session);
    if (_notificationService.isRunning) {
      await _notificationService.update(
        title: l10n.aruNotificationTitle,
        text: text,
      );
    } else {
      await _notificationService.start(
        title: l10n.aruNotificationTitle,
        text: text,
      );
    }
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AppHelpBottomSheet(
            title: l10n.helpAruTitle,
            sections: [
              AppHelpSection(
                icon: AppIcons.scheduleRounded,
                body: l10n.helpAruBody,
              ),
              AppHelpSection(
                icon: AppIcons.infoOutline,
                body: l10n.aruHelpStatusIcons,
              ),
              AppHelpSection(
                icon: AppIcons.graphicEqRounded,
                body: l10n.aruSetupHelpBody,
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(aruStateProvider);
    final session = ref.watch(aruSessionProvider);
    final ringBuffer = ref.watch(ringBufferProvider);
    final captureState = ref.watch(captureStateProvider);
    final isRecording = state == AruControllerState.recording;
    final spectrogramActive =
        isRecording &&
        captureState == CaptureState.capturing &&
        _tabController.index == 1;

    ref.listen<int>(confidenceThresholdProvider, (_, next) {
      ref.read(liveControllerProvider).setConfidenceThreshold(next);
    });
    ref.listen<int?>(scorePoolingWindowsProvider, (_, next) {
      ref.read(liveControllerProvider).setPoolingWindows(next);
    });
    ref.listen<String>(scorePoolingProvider, (_, next) {
      ref.read(liveControllerProvider).setPoolingMode(next);
    });
    ref.listen<double>(sensitivityProvider, (_, next) {
      ref.read(liveControllerProvider).setSensitivity(next);
    });
    ref.listen<double>(audioGainProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setGain(next);
    });
    ref.listen<double>(highPassFilterProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setHighPassCutoff(next);
    });

    return PopScope(
      canPop: session == null || state == AruControllerState.completed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmStop();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child:
              session == null
                  ? Center(child: Text(l10n.aruNoActiveDeployment))
                  : _buildBody(
                    context,
                    theme: theme,
                    l10n: l10n,
                    state: state,
                    session: session,
                    ringBuffer: ringBuffer,
                    spectrogramActive: spectrogramActive,
                  ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required ThemeData theme,
    required AppLocalizations l10n,
    required AruControllerState state,
    required LiveSession session,
    required RingBuffer ringBuffer,
    required bool spectrogramActive,
  }) {
    final isRecording = state == AruControllerState.recording;
    final visibleDetections = _visibleDetections(session, state);
    final showDetectionPane =
        _tabController.index == 0 || _tabController.index == 1;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final statusBar = _AruStatusBar(
      state: state,
      session: session,
      onStop: _confirmStop,
      onHelp: _showHelp,
    );
    final tabBar = TabBar(
      controller: _tabController,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      indicatorWeight: 2,
      labelStyle: theme.textTheme.labelSmall,
      tabs: [
        Tab(
          icon: const Icon(AppIcons.infoOutline, size: 18),
          text: l10n.aruTabStatus,
        ),
        Tab(
          icon: const Icon(AppIcons.graphicEq, size: 18),
          text: l10n.surveyTabSpectrogram,
        ),
        Tab(
          icon: const Icon(AppIcons.scheduleRounded, size: 18),
          text: l10n.aruSetupSchedule,
        ),
        Tab(
          icon: const Icon(AppIcons.summaryChart, size: 18),
          text: l10n.surveyTabSummary,
        ),
      ],
    );
    final tabContent = TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatusPanel(session: session, state: state),
        _SpectrogramPanel(isActive: spectrogramActive, state: state),
        _SchedulePanel(session: session),
        _SummaryPanel(session: session),
      ],
    );
    final statsBar = _AruStatsBar(session: session, ringBuffer: ringBuffer);
    final detectionPane = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: DetectionList(
          detections: visibleDetections,
          isActive: isRecording,
          emptyIcon: isRecording ? null : AppIcons.scheduleRounded,
          emptyTitle: isRecording ? null : l10n.aruWaitingDetectionsTitle,
          emptySubtitle: isRecording ? null : l10n.aruWaitingDetectionsBody,
        ),
      ),
    );

    if (isLandscape && showDetectionPane) {
      return Column(
        children: [
          statusBar,
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      tabBar,
                      Expanded(child: tabContent),
                      statsBar,
                    ],
                  ),
                ),
                Expanded(child: detectionPane),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        statusBar,
        tabBar,
        Expanded(flex: showDetectionPane ? 2 : 1, child: tabContent),
        if (showDetectionPane) ...[
          statsBar,
          Expanded(flex: 3, child: detectionPane),
        ],
      ],
    );
  }
}

class _AruStatusBar extends StatefulWidget {
  const _AruStatusBar({
    required this.state,
    required this.session,
    required this.onStop,
    required this.onHelp,
  });

  final AruControllerState state;
  final LiveSession session;
  final VoidCallback onStop;
  final VoidCallback onHelp;

  @override
  State<_AruStatusBar> createState() => _AruStatusBarState();
}

class _AruStatusBarState extends State<_AruStatusBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _AruStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive && _timer == null) {
      _startTimer();
    } else if (!_isActive && _timer != null) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  bool get _isActive => widget.state != AruControllerState.completed;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final snapshot = _scheduleSnapshot(widget.session);
    final current = snapshot?.currentWindow;
    final next = snapshot?.nextWindow;
    final now = DateTime.now();
    final isTest = current != null && _isTestWindow(widget.session, current);
    final label =
        isTest
            ? l10n.aruTestRun
            : switch (widget.state) {
              AruControllerState.recording => l10n.aruActiveRecording,
              AruControllerState.completed => l10n.aruActiveCompleted,
              _ => l10n.aruNextCycle,
            };
    final detail =
        current != null
            ? _formatDuration(current.end.difference(now))
            : next != null
            ? _formatDuration(next.start.difference(now))
            : _formatDuration(widget.session.duration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.stopRounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed:
                _isActive ? widget.onStop : () => Navigator.of(context).pop(),
            tooltip: l10n.aruStopDeployment,
            color: _isActive ? theme.colorScheme.error : null,
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.state == AruControllerState.recording
                        ? AppIcons.fiberManualRecordRounded
                        : AppIcons.scheduleRounded,
                    size: 18,
                    color:
                        widget.state == AruControllerState.recording
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$label  $detail',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color:
                            widget.state == AruControllerState.recording
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              AppIcons.helpOutlineRounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: widget.onHelp,
            tooltip: l10n.helpAruTitle,
          ),
          IconButton(
            icon: Icon(
              AppIcons.tuneRounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => const SettingsScreen(
                        settingsContext: SettingsContext.survey,
                      ),
                ),
              );
            },
            tooltip: l10n.settings,
          ),
        ],
      ),
    );
  }
}

class _AruStatsBar extends StatelessWidget {
  const _AruStatsBar({required this.session, required this.ringBuffer});

  final LiveSession session;
  final RingBuffer ringBuffer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final level = ringBuffer.rmsLevel();
    final levelLabel =
        level <= 0 ? '0%' : '${(level * 100).clamp(1, 99).round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StatChip(icon: AppIcons.mic, value: levelLabel, style: style),
          StatChip(
            icon: AppIcons.checkCircleRounded,
            value: '${_completedCycleCount(session)}',
            style: style,
          ),
          StatChip(
            icon: AppIcons.detections,
            value: '${session.detections.length}',
            style: style,
          ),
          StatChip(
            icon: AppIcons.species,
            value: '${session.uniqueSpeciesCount}',
            style: style,
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.session,
    required this.state,
  });

  final LiveSession session;
  final AruControllerState state;

  @override
  Widget build(BuildContext context) {
    final snapshot = _scheduleSnapshot(session);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: [
        _ScheduleFocusCard(
          state: state,
          session: session,
          currentWindow: snapshot?.currentWindow,
          nextWindow: snapshot?.nextWindow,
        ),
      ],
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.session});

  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final metadata = session.aruMetadata;
    final schedule =
        metadata == null
            ? null
            : AruScheduleCalculator(metadata.toScheduleConfig());
    final now = DateTime.now();
    final windows = schedule?.nextWindows(now, count: 10) ?? const [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text(l10n.aruNextCyclesPreview, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (windows.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(AppIcons.checkCircleRounded),
              title: Text(l10n.aruActiveCompleted),
            ),
          )
        else
          for (final window in windows)
            ListTile(
              leading: Icon(
                window.contains(now)
                    ? AppIcons.fiberManualRecordRounded
                    : AppIcons.scheduleRounded,
                color:
                    window.contains(now)
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                _isTestWindow(session, window)
                    ? l10n.aruTestRun
                    : DateFormat.yMMMd().add_jm().format(window.start),
              ),
              subtitle: Text(_windowLabel(window)),
            ),
      ],
    );
  }
}

class _ScheduleFocusCard extends StatelessWidget {
  const _ScheduleFocusCard({
    required this.state,
    required this.session,
    required this.currentWindow,
    required this.nextWindow,
  });

  final AruControllerState state;
  final LiveSession session;
  final AruCycleWindow? currentWindow;
  final AruCycleWindow? nextWindow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRecording = state == AruControllerState.recording;
    final currentIsTest =
        currentWindow != null && _isTestWindow(session, currentWindow!);
    final nextIsTest = nextWindow != null && _isTestWindow(session, nextWindow!);
    final icon =
        isRecording
            ? AppIcons.fiberManualRecordRounded
            : AppIcons.scheduleRounded;
    final color =
        isRecording ? theme.colorScheme.error : theme.colorScheme.primary;
    final title =
        currentIsTest || nextIsTest
            ? l10n.aruTestRun
            : isRecording
            ? l10n.aruActiveRecording
            : l10n.aruActiveWaiting;
    final body =
        currentWindow != null
            ? '${_windowLabel(currentWindow!)} - ${l10n.fileAnalysisEtaRemaining(_formatDuration(currentWindow!.end.difference(DateTime.now())))}'
            : nextWindow != null
            ? '${DateFormat.yMMMd().add_jm().format(nextWindow!.start)} - ${l10n.fileAnalysisEtaRemaining(_formatDuration(nextWindow!.start.difference(DateTime.now())))}'
            : l10n.aruActiveCompleted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectrogramPanel extends ConsumerWidget {
  const _SpectrogramPanel({required this.isActive, required this.state});

  final bool isActive;
  final AruControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ringBuffer = ref.watch(ringBufferProvider);

    if (isActive) {
      return _AruSpectrogram(ringBuffer: ringBuffer, isActive: true);
    }

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state == AruControllerState.recording
                ? l10n.surveyStarting
                : l10n.aruActiveWaiting,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AruSpectrogram extends ConsumerWidget {
  const _AruSpectrogram({required this.ringBuffer, required this.isActive});

  final RingBuffer ringBuffer;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fftSize = ref.watch(fftSizeProvider);
    final colorMap = ref.watch(colorMapProvider);
    final dbFloor = ref.watch(dbFloorProvider);
    final dbCeiling = ref.watch(dbCeilingProvider);
    final durationSec = ref.watch(spectrogramDurationProvider);
    final maxFreq = ref.watch(spectrogramMaxFreqProvider);
    final logAmplitude = ref.watch(logAmplitudeProvider);
    final quality = ref.watch(spectrogramQualityProvider);

    final hopSize = fftSize ~/ 2;
    const sampleRate = 32000;
    final maxColumns = (durationSec * sampleRate / hopSize).round();

    return SpectrogramWidget(
      ringBuffer: ringBuffer,
      isActive: isActive,
      fftSize: fftSize,
      colorMapName: colorMap,
      dbFloor: dbFloor,
      dbCeiling: dbCeiling,
      maxColumns: maxColumns,
      showFrequencyAxis: false,
      showTimeAxis: false,
      maxDisplayFrequency: maxFreq,
      logAmplitude: logAmplitude,
      filterQuality: spectrogramFilterQualityFromString(quality),
      quality: quality,
    );
  }
}

class _SummaryPanel extends StatefulWidget {
  const _SummaryPanel({required this.session});

  final LiveSession session;

  @override
  State<_SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends State<_SummaryPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = widget.session;
    final elapsed = (session.endTime ?? DateTime.now()).difference(
      session.startTime,
    );
    final species = _speciesSummary(session.detections);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _MetricRow(
                  icon: AppIcons.timerRounded,
                  label: l10n.aruElapsedTime,
                  value: _formatDuration(elapsed),
                ),
                _MetricRow(
                  icon: AppIcons.libraryMusic,
                  label: l10n.aruRecordedAudio,
                  value: _formatDuration(session.duration),
                ),
                _MetricRow(
                  icon: AppIcons.detections,
                  label: l10n.surveyTabSummaryDetections,
                  value: '${session.detections.length}',
                ),
                _MetricRow(
                  icon: AppIcons.species,
                  label: l10n.surveyTabSummarySpecies,
                  value: '${session.uniqueSpeciesCount}',
                ),
              ],
            ),
          ),
        ),
        if (species.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.surveyTabSummarySpecies,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final item in species.take(12))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.commonName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.count}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AruSpeciesSummary {
  const _AruSpeciesSummary({required this.commonName, required this.count});

  final String commonName;
  final int count;
}

List<_AruSpeciesSummary> _speciesSummary(List<DetectionRecord> detections) {
  final bySpecies = <String, _AruSpeciesSummary>{};
  for (final detection in detections) {
    final existing = bySpecies[detection.scientificName];
    bySpecies[detection.scientificName] = _AruSpeciesSummary(
      commonName: detection.commonName,
      count: (existing?.count ?? 0) + 1,
    );
  }
  final list = bySpecies.values.toList();
  list.sort((a, b) => b.count.compareTo(a.count));
  return list;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

AruScheduleSnapshot? _scheduleSnapshot(LiveSession session) {
  final metadata = session.aruMetadata;
  if (metadata == null) return null;
  return AruScheduleCalculator(
    metadata.toScheduleConfig(),
  ).snapshotAt(DateTime.now());
}

List<DetectionRecord> _visibleDetections(
  LiveSession session,
  AruControllerState state,
) {
  final current = _scheduleSnapshot(session)?.currentWindow;
  if (state == AruControllerState.recording && current != null) {
    return session.detections
        .where(
          (detection) =>
              !detection.timestamp.isBefore(current.start) &&
              detection.timestamp.isBefore(current.end),
        )
        .toList()
        .reversed
        .toList();
  }
  return session.detections.reversed.take(20).toList();
}

int _completedCycleCount(LiveSession session) {
  return (session.aruMetadata?.cycles ?? const <AruCycleMetadata>[])
      .where(
        (cycle) =>
            cycle.status == AruCycleStatus.completed ||
            cycle.status == AruCycleStatus.stopped ||
            cycle.status == AruCycleStatus.partial,
      )
      .length;
}

bool _isTestWindow(LiveSession session, AruCycleWindow window) {
  return session.aruMetadata?.testCycleEnabled == true && window.index == 0;
}

String _windowLabel(AruCycleWindow window) {
  final formatter = DateFormat.jm();
  return '${formatter.format(window.start)} - ${formatter.format(window.end)}';
}

String _formatDuration(Duration duration) {
  if (duration.isNegative) return '0 s';
  if (duration.inHours >= 1) {
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final minutePart = minutes > 0 ? ' $minutes min' : '';
    final secondPart = ' $seconds s';
    return '${duration.inHours} h$minutePart$secondPart';
  }
  if (duration.inMinutes >= 1) {
    final seconds = duration.inSeconds % 60;
    return '${duration.inMinutes} min $seconds s';
  }
  return '${duration.inSeconds} s';
}

String _notificationText(
  AppLocalizations l10n,
  AruControllerState state,
  LiveSession session,
) {
  final status = switch (state) {
    AruControllerState.recording => l10n.aruActiveRecording,
    AruControllerState.completed => l10n.aruActiveCompleted,
    _ => l10n.aruActiveWaiting,
  };
  final snapshot = _scheduleSnapshot(session);
  if (snapshot?.currentWindow != null) {
    return '$status - ${_windowLabel(snapshot!.currentWindow!)}';
  }
  if (snapshot?.nextWindow != null) {
    return '$status - ${DateFormat.Hm().format(snapshot!.nextWindow!.start)}';
  }
  return '$status - ${l10n.aruCompletedCycles}: ${_completedCycleCount(session)}';
}
