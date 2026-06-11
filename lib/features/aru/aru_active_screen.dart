import 'dart:async';

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
  bool _stopping = false;
  bool _tickBusy = false;
  bool _inferenceStarting = false;
  bool _aruInferenceActive = false;

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
        windowDuration: ref.read(windowDurationProvider),
        inferenceRate: ref.read(surveyInferenceRateProvider),
        confidenceThreshold: ref.read(confidenceThresholdProvider),
        speciesFilterMode: ref.read(speciesFilterModeProvider),
        recordingMode: RecordingMode.off,
        geoScores: await ref.read(geoScoresProvider.future),
        geoThreshold: ref.read(geoThresholdProvider),
        geoModelSpeciesNames: await ref.read(
          geoModelSpeciesNamesProvider.future,
        ),
        poolingWindows: ref.read(scorePoolingWindowsProvider),
        poolingMode: ref.read(scorePoolingProvider),
        sensitivity: ref.read(sensitivityProvider),
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
    final controller = ref.read(aruControllerProvider);
    await _stopInference();
    await controller.stop();
    if (!mounted) return;
    ref.read(aruStateProvider.notifier).state = controller.state;
    ref.read(aruSessionProvider.notifier).state = controller.session;
    await _notificationService.stop();
    if (!mounted) return;
    setState(() => _stopping = false);
    Navigator.of(context).pop();
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final showFullPageTab =
        _tabController.index == 2 || _tabController.index == 3;
    final isRecording = state == AruControllerState.recording;
    final visibleDetections = _visibleDetections(session, state);

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
          icon: const Icon(AppIcons.scheduleRounded, size: 18),
          text: l10n.aruSetupSchedule,
        ),
        Tab(
          icon: const Icon(AppIcons.graphicEq, size: 18),
          text: l10n.surveyTabSpectrogram,
        ),
        Tab(
          icon: const Icon(AppIcons.detections, size: 18),
          text: l10n.surveyTabSummaryDetections,
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
        _SchedulePanel(session: session, state: state),
        _SpectrogramPanel(isActive: spectrogramActive, state: state),
        _DetectionsPanel(detections: visibleDetections, isActive: isRecording),
        _SummaryPanel(session: session),
      ],
    );
    final statsBar = _AruStatsBar(session: session, ringBuffer: ringBuffer);
    final detectionList = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: DetectionList(
          detections: visibleDetections,
          isActive: isRecording,
        ),
      ),
    );

    if (isLandscape) {
      return Column(
        children: [
          statusBar,
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      tabBar,
                      Expanded(child: tabContent),
                      if (!showFullPageTab) statsBar,
                    ],
                  ),
                ),
                if (!showFullPageTab) Expanded(flex: 1, child: detectionList),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      children: [
        statusBar,
        tabBar,
        Expanded(flex: showFullPageTab ? 1 : 2, child: tabContent),
        if (!showFullPageTab) ...[
          statsBar,
          Expanded(flex: 3, child: detectionList),
        ],
        const SizedBox(height: 16),
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
    final label = switch (widget.state) {
      AruControllerState.recording => l10n.aruActiveRecording,
      AruControllerState.completed => l10n.aruActiveCompleted,
      _ => l10n.aruActiveWaiting,
    };
    final detail =
        current != null
            ? _formatDuration(current.end.difference(DateTime.now()))
            : next != null
            ? _formatDuration(next.start.difference(DateTime.now()))
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

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.session, required this.state});

  final LiveSession session;
  final AruControllerState state;

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
    final snapshot = schedule?.snapshotAt(now);
    final current = snapshot?.currentWindow;
    final next = snapshot?.nextWindow;
    final windows = schedule?.nextWindows(now, count: 3) ?? const [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _ScheduleFocusCard(
          state: state,
          currentWindow: current,
          nextWindow: next,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _MetricRow(
                  icon: AppIcons.timerRounded,
                  label: l10n.aruCycleDuration,
                  value: _formatDuration(
                    Duration(seconds: metadata?.cycleDurationSeconds ?? 0),
                  ),
                ),
                _MetricRow(
                  icon: AppIcons.repeatRounded,
                  label: l10n.aruRepeatInterval,
                  value: _formatDuration(
                    Duration(seconds: metadata?.repeatIntervalSeconds ?? 0),
                  ),
                ),
                _MetricRow(
                  icon: AppIcons.stopCircle,
                  label: l10n.aruScheduleEnd,
                  value: _scheduleEndSummary(l10n, metadata),
                ),
                _MetricRow(
                  icon: AppIcons.batteryChargingFull,
                  label: l10n.aruLowBatteryStop,
                  value:
                      metadata?.lowBatteryStopPercent != null
                          ? '${metadata!.lowBatteryStopPercent}%'
                          : l10n.settingsFilterOff,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.aruNextCycle, style: theme.textTheme.titleSmall),
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
            Card(
              child: ListTile(
                leading: const Icon(AppIcons.scheduleRounded),
                title: Text(DateFormat.yMMMd().add_jm().format(window.start)),
                subtitle: Text(_windowLabel(window)),
              ),
            ),
      ],
    );
  }
}

class _ScheduleFocusCard extends StatelessWidget {
  const _ScheduleFocusCard({
    required this.state,
    required this.currentWindow,
    required this.nextWindow,
  });

  final AruControllerState state;
  final AruCycleWindow? currentWindow;
  final AruCycleWindow? nextWindow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRecording = state == AruControllerState.recording;
    final icon =
        isRecording
            ? AppIcons.fiberManualRecordRounded
            : AppIcons.scheduleRounded;
    final color =
        isRecording ? theme.colorScheme.error : theme.colorScheme.primary;
    final title = isRecording ? l10n.aruActiveRecording : l10n.aruActiveWaiting;
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
    final ringBuffer = ref.watch(ringBufferProvider);

    return Padding(
      padding: const EdgeInsets.all(8),
      child:
          isActive
              ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _AruSpectrogram(ringBuffer: ringBuffer, isActive: true),
              )
              : Center(
                child: Text(
                  state == AruControllerState.recording
                      ? l10n.surveyStarting
                      : l10n.aruActiveWaiting,
                  textAlign: TextAlign.center,
                ),
              ),
    );
  }
}

class _DetectionsPanel extends StatelessWidget {
  const _DetectionsPanel({required this.detections, required this.isActive});

  final List<DetectionRecord> detections;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DetectionList(detections: detections, isActive: isActive),
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

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.session});

  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final metadata = session.aruMetadata;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _MetricRow(
                  icon: AppIcons.checkCircleRounded,
                  label: l10n.aruCompletedCycles,
                  value: '${_completedCycleCount(session)}',
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
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if ((metadata?.stationId ?? '').trim().isNotEmpty)
                  _MetricRow(
                    icon: AppIcons.sdStorage,
                    label: l10n.aruStationId,
                    value: metadata!.stationId!,
                  ),
                _MetricRow(
                  icon: AppIcons.fiberManualRecordRounded,
                  label: l10n.surveyRecordingMode,
                  value: _recordingModeSummaryLabel(
                    l10n,
                    metadata?.recordingMode,
                  ),
                ),
                _MetricRow(
                  icon: AppIcons.stopCircle,
                  label: l10n.aruScheduleEnd,
                  value: _scheduleEndSummary(l10n, metadata),
                ),
                _MetricRow(
                  icon: AppIcons.scheduleRounded,
                  label: l10n.aruNextCycle,
                  value: _nextCycleLabel(session),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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

String _nextCycleLabel(LiveSession session) {
  final next = _scheduleSnapshot(session)?.nextWindow;
  if (next == null) return '-';
  return DateFormat.yMMMd().add_jm().format(next.start);
}

String _windowLabel(AruCycleWindow window) {
  final formatter = DateFormat.jm();
  return '${formatter.format(window.start)} - ${formatter.format(window.end)}';
}

String _scheduleEndSummary(
  AppLocalizations l10n,
  AruDeploymentMetadata? metadata,
) {
  if (metadata == null) return '-';
  if (metadata.scheduleEnd != null) {
    return DateFormat.yMMMd().add_jm().format(metadata.scheduleEnd!.toLocal());
  }
  if (metadata.maxCycles != null) return '${metadata.maxCycles}';
  return l10n.aruScheduleNoLimit;
}

String _recordingModeSummaryLabel(AppLocalizations l10n, String? mode) {
  return switch (mode) {
    'full' => l10n.surveyRecordingFull,
    'detections' || 'detectionsOnly' => l10n.surveyRecordingDetections,
    'off' => l10n.surveyRecordingOff,
    _ => '-',
  };
}

String _formatDuration(Duration duration) {
  if (duration.isNegative) return '0 s';
  if (duration.inHours >= 1) {
    final minutes = duration.inMinutes % 60;
    return minutes == 0
        ? '${duration.inHours} h'
        : '${duration.inHours} h $minutes min';
  }
  if (duration.inMinutes >= 1) return '${duration.inMinutes} min';
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
