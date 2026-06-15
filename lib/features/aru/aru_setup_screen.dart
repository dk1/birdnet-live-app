import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:birdnet_live/shared/widgets/app_help_bottom_sheet.dart';
import 'package:birdnet_live/shared/widgets/map_picker_screen.dart';
import 'package:birdnet_live/shared/widgets/site_context_card.dart';
import 'package:birdnet_live/shared/widgets/weather_setup_card.dart';
import 'package:birdnet_live/shared/widgets/wizard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../survey/detection_sampler.dart';
import 'aru_active_screen.dart';
import 'aru_controller.dart';
import 'aru_defaults.dart';
import 'aru_notification.dart';
import 'aru_providers.dart';
import 'aru_schedule.dart';
import 'aru_storage_estimator.dart';

enum _LocationChoice { gps, manual, skip }

enum _ScheduleEndMode { manual, cycles, dateTime }

class AruSetupScreen extends ConsumerStatefulWidget {
  const AruSetupScreen({super.key});

  @override
  ConsumerState<AruSetupScreen> createState() => _AruSetupScreenState();
}

class _AruSetupScreenState extends ConsumerState<AruSetupScreen> {
  static const _totalSteps = 5;
  static const _maxGpsAttempts = 5;
  static const _gpsRetryDelay = Duration(seconds: 5);
  static const _gpsCacheMaxAge = Duration(minutes: 2);

  final _deploymentController = TextEditingController();
  final _stationController = TextEditingController();
  final _observerController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  int _step = 0;
  _LocationChoice _locationChoice = _LocationChoice.gps;
  double? _latitude;
  double? _longitude;
  bool _gpsFetching = false;
  int _gpsAttempts = 0;
  int _gpsRequestSerial = 0;
  Timer? _gpsRetryTimer;
  Duration _cycleDuration = AruDefaults.defaultCycleDuration;
  Duration _repeatInterval = AruDefaults.defaultRepeatInterval;
  _ScheduleEndMode _scheduleEndMode = _ScheduleEndMode.cycles;
  late DateTime _scheduleEnd;
  int _maxCycles = AruDefaults.defaultMaxCycles;
  int _lowBatteryStop = AruDefaults.defaultLowBatteryStopPercent;
  AruDielPattern _dielPattern = AruDielPattern.anyTime;
  RecordingMode _recordingMode = RecordingMode.full;
  SamplingMode _samplingMode = SamplingMode.smart;
  int _topNPerSpecies = 10;
  bool _testCycleEnabled = true;
  bool _eachCycleIsSession = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _scheduleEnd = _defaultScheduleEnd();
    _fetchGpsLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = ref.read(aruSessionProvider);
      final state = ref.read(aruStateProvider);
      if (session != null &&
          state != AruControllerState.completed &&
          state != AruControllerState.idle) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AruActiveScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _gpsRetryTimer?.cancel();
    _deploymentController.dispose();
    _stationController.dispose();
    _observerController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
  }

  void _next() {
    if (_step == 0 && !_validateLocationSelection()) {
      return;
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    }
  }

  bool _validateLocationSelection() {
    final l10n = AppLocalizations.of(context)!;
    String? error;

    if (_locationChoice == _LocationChoice.manual) {
      _parseManualLocation();
      if (_latitude == null || _longitude == null) {
        error = l10n.aruManualLocationInvalid;
      }
    } else if (_locationChoice == _LocationChoice.gps &&
        (_latitude == null || _longitude == null)) {
      error = l10n.aruGpsFixRequired;
    }

    if (error == null) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
    return false;
  }

  Future<void> _fetchGpsLocation({
    bool resetAttempts = true,
    bool forceFresh = false,
  }) async {
    if (resetAttempts) {
      _gpsRetryTimer?.cancel();
      _gpsRetryTimer = null;
      _gpsAttempts = 0;
    }
    _gpsAttempts++;
    final serial = ++_gpsRequestSerial;
    if (!_gpsFetching) setState(() => _gpsFetching = true);

    try {
      final service = ref.read(locationServiceProvider);
      final location = await service.getCurrentLocation(
        maxAge: forceFresh ? Duration.zero : _gpsCacheMaxAge,
      );
      if (!mounted || serial != _gpsRequestSerial) return;
      if (location != null) {
        _gpsRetryTimer?.cancel();
        _gpsRetryTimer = null;
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          _gpsFetching = false;
        });
        if (service.lastFetchUsedCachedFallback) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.gpsStaleWarning),
                duration: const Duration(seconds: 4),
              ),
            );
        }
        return;
      }
      _scheduleGpsRetryOrStop();
    } catch (_) {
      if (!mounted || serial != _gpsRequestSerial) return;
      _scheduleGpsRetryOrStop();
    }
  }

  void _scheduleGpsRetryOrStop() {
    if (!mounted ||
        _locationChoice != _LocationChoice.gps ||
        _gpsAttempts >= _maxGpsAttempts) {
      if (mounted) setState(() => _gpsFetching = false);
      return;
    }
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = Timer(_gpsRetryDelay, () {
      if (!mounted || _locationChoice != _LocationChoice.gps) return;
      _fetchGpsLocation(resetAttempts: false);
    });
  }

  void _cancelGpsAutoRetry() {
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = null;
    _gpsRequestSerial++;
    if (_gpsFetching && mounted) {
      setState(() => _gpsFetching = false);
    }
  }

  void _parseManualLocation() {
    _latitude = double.tryParse(_latController.text)?.clamp(-90, 90).toDouble();
    _longitude =
        double.tryParse(_lonController.text)?.clamp(-180, 180).toDouble();
  }

  static DateTime _defaultScheduleEnd() {
    final now = DateTime.now().add(const Duration(days: 1));
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  DateTime? get _selectedScheduleEnd =>
      _scheduleEndMode == _ScheduleEndMode.dateTime ? _scheduleEnd : null;

  int? get _selectedMaxCycles =>
      _scheduleEndMode == _ScheduleEndMode.cycles ? _maxCycles : null;

  int? get _selectedLowBatteryStop =>
      _lowBatteryStop > 0 ? _lowBatteryStop : null;

  Future<void> _start() async {
    if (_starting || !_validateLocationSelection()) return;
    setState(() => _starting = true);

    await AruNotificationService.ensurePermission();
    if (!mounted) return;

    final now = DateTime.now();
    final latitude = _locationChoice == _LocationChoice.skip ? null : _latitude;
    final longitude =
        _locationChoice == _LocationChoice.skip ? null : _longitude;
    final metadata = AruDeploymentMetadata(
      deploymentName: _emptyToNull(_deploymentController.text),
      stationId: _emptyToNull(_stationController.text),
      scheduleStart: now,
      cycleDurationSeconds: _cycleDuration.inSeconds,
      repeatIntervalSeconds: _repeatInterval.inSeconds,
      scheduleEnd: _selectedScheduleEnd,
      maxCycles: _selectedMaxCycles,
      lowBatteryStopPercent: _selectedLowBatteryStop,
      dielPattern: _dielPattern,
      latitude: latitude,
      longitude: longitude,
      recordingMode: _recordingMode.name,
      recordingFormat: ref.read(recordingFormatProvider),
      samplingMode:
          _recordingMode == RecordingMode.detectionsOnly
              ? _samplingMode.name
              : SamplingMode.all.name,
      topNPerSpecies: _topNPerSpecies,
      testCycleEnabled: _testCycleEnabled,
      eachCycleIsSession: _eachCycleIsSession,
    );

    final settings = SessionSettings(
      windowDuration: ref.read(windowDurationProvider),
      confidenceThreshold: ref.read(confidenceThresholdProvider),
      inferenceRate: ref.read(inferenceRateProvider),
      speciesFilterMode: ref.read(speciesFilterModeProvider),
      sensitivity: ref.read(sensitivityProvider),
      poolingMode: ref.read(scorePoolingProvider),
      poolingWindows: ref.read(scorePoolingWindowsProvider),
      gainLinear: ref.read(audioGainProvider),
      highPassHz: ref.read(highPassFilterProvider),
    );

    final repo = ref.read(sessionRepositoryProvider);
    final sessionNumber = await repo.nextSessionNumber(SessionType.aru);

    final controller = ref.read(aruControllerProvider);
    await controller.startDeployment(
      sessionId: 'aru-${now.toUtc().toIso8601String().replaceAll(':', '-')}',
      settings: settings,
      metadata: metadata,
      observerName: _emptyToNull(_observerController.text),
      latitude: latitude,
      longitude: longitude,
      sessionNumber: sessionNumber,
    );
    ref.read(aruStateProvider.notifier).state = controller.state;
    ref.read(aruSessionProvider.notifier).state = controller.session;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AruActiveScreen()),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AppHelpBottomSheet(
            title: l10n.aruSetupHelpTitle,
            sections: [
              AppHelpSection(
                icon: AppIcons.sdStorage,
                body: l10n.aruSetupHelpBody,
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLastStep = _step == _totalSteps - 1;

    return WizardScaffold(
      title: l10n.aruSetupTitle,
      step: _step,
      totalSteps: _totalSteps,
      actions: [
        IconButton(
          icon: const Icon(AppIcons.helpOutlineRounded, size: 20),
          tooltip: l10n.aruSetupHelpTitle,
          onPressed: _showHelp,
        ),
        IconButton(
          icon: const Icon(AppIcons.tuneRounded, size: 20),
          tooltip: l10n.settings,
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
        ),
      ],
      onBack: _starting ? null : _back,
      onNext: _starting ? null : (isLastStep ? _start : _next),
      backLabel: _step == 0 ? l10n.cancel : l10n.surveyBack,
      nextLabel: isLastStep ? l10n.aruStartDeployment : l10n.surveyNext,
      nextIcon: isLastStep ? AppIcons.playArrowRounded : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_step) {
          0 => _DetailsStep(
            key: const ValueKey(0),
            deploymentController: _deploymentController,
            stationController: _stationController,
            observerController: _observerController,
            locationChoice: _locationChoice,
            latitude: _latitude,
            longitude: _longitude,
            gpsFetching: _gpsFetching,
            latController: _latController,
            lonController: _lonController,
            onLocationChoiceChanged: (choice) {
              setState(() => _locationChoice = choice);
              if (choice == _LocationChoice.gps) {
                _fetchGpsLocation();
              } else {
                _cancelGpsAutoRetry();
              }
            },
            onFetchGps: () => _fetchGpsLocation(forceFresh: true),
            onMapPick: (lat, lon) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
                _latController.text = lat.toStringAsFixed(6);
                _lonController.text = lon.toStringAsFixed(6);
              });
            },
          ),
          1 => _ParametersStep(
            key: const ValueKey(1),
            recordingMode: _recordingMode,
            onRecordingModeChanged:
                (value) => setState(() => _recordingMode = value),
            samplingMode: _samplingMode,
            onSamplingModeChanged:
                (value) => setState(() => _samplingMode = value),
            topNPerSpecies: _topNPerSpecies,
            onTopNPerSpeciesChanged:
                (value) => setState(() => _topNPerSpecies = value),
          ),
          2 => _ScheduleStep(
            key: const ValueKey(2),
            cycleDuration: _cycleDuration,
            repeatInterval: _repeatInterval,
            scheduleEndMode: _scheduleEndMode,
            scheduleEnd: _scheduleEnd,
            maxCycles: _maxCycles,
            lowBatteryStop: _lowBatteryStop,
            dielPattern: _dielPattern,
            latitude:
                _locationChoice == _LocationChoice.skip ? null : _latitude,
            longitude:
                _locationChoice == _LocationChoice.skip ? null : _longitude,
            testCycleEnabled: _testCycleEnabled,
            eachCycleIsSession: _eachCycleIsSession,
            onCycleDurationChanged:
                (value) => setState(() {
                  _cycleDuration = value;
                  if (_repeatInterval < value) {
                    _repeatInterval = _nearestRepeatInterval(value);
                  }
                }),
            onRepeatIntervalChanged:
                (value) => setState(() => _repeatInterval = value),
            onScheduleEndModeChanged:
                (value) => setState(() => _scheduleEndMode = value),
            onScheduleEndChanged:
                (value) => setState(() => _scheduleEnd = value),
            onMaxCyclesChanged: (value) => setState(() => _maxCycles = value),
            onLowBatteryStopChanged:
                (value) => setState(() => _lowBatteryStop = value),
            onDielPatternChanged:
                (value) => setState(() => _dielPattern = value),
            onTestCycleEnabledChanged:
                (value) => setState(() => _testCycleEnabled = value),
            onEachCycleIsSessionChanged:
                (value) => setState(() => _eachCycleIsSession = value),
          ),
          3 => const _FieldTipsStep(key: ValueKey(3)),
          _ => _ReadyStep(
            key: const ValueKey(4),
            deploymentName: _deploymentController.text,
            stationId: _stationController.text,
            observerName: _observerController.text,
            latitude:
                _locationChoice == _LocationChoice.skip ? null : _latitude,
            longitude:
                _locationChoice == _LocationChoice.skip ? null : _longitude,
            cycleDuration: _cycleDuration,
            repeatInterval: _repeatInterval,
            scheduleEndMode: _scheduleEndMode,
            scheduleEnd: _selectedScheduleEnd,
            maxCycles: _selectedMaxCycles,
            lowBatteryStop: _lowBatteryStop,
            dielPattern: _dielPattern,
            recordingMode: _recordingMode,
            samplingMode: _samplingMode,
            topNPerSpecies: _topNPerSpecies,
            testCycleEnabled: _testCycleEnabled,
            eachCycleIsSession: _eachCycleIsSession,
          ),
        },
      ),
    );
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

Duration _nearestRepeatInterval(Duration minimum) {
  return AruDefaults.repeatIntervalOptions.firstWhere(
    (duration) => duration >= minimum,
    orElse: () => AruDefaults.repeatIntervalOptions.last,
  );
}

class _DetailsStep extends ConsumerWidget {
  const _DetailsStep({
    required this.deploymentController,
    required this.stationController,
    required this.observerController,
    required this.locationChoice,
    required this.latitude,
    required this.longitude,
    required this.gpsFetching,
    required this.latController,
    required this.lonController,
    required this.onLocationChoiceChanged,
    required this.onFetchGps,
    required this.onMapPick,
    super.key,
  });

  final TextEditingController deploymentController;
  final TextEditingController stationController;
  final TextEditingController observerController;
  final _LocationChoice locationChoice;
  final double? latitude;
  final double? longitude;
  final bool gpsFetching;
  final TextEditingController latController;
  final TextEditingController lonController;
  final ValueChanged<_LocationChoice> onLocationChoiceChanged;
  final VoidCallback onFetchGps;
  final void Function(double lat, double lon) onMapPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        TextField(
          controller: deploymentController,
          decoration: InputDecoration(
            labelText: l10n.aruDeploymentName,
            prefixIcon: const Icon(AppIcons.noteAdd),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: stationController,
          decoration: InputDecoration(
            labelText: l10n.aruStationId,
            prefixIcon: const Icon(AppIcons.sdStorage),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: observerController,
          decoration: InputDecoration(
            labelText: l10n.aruObserverName,
            prefixIcon: const Icon(AppIcons.personRounded),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.surveyLocation,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_LocationChoice>(
          segments: [
            ButtonSegment(
              value: _LocationChoice.gps,
              label: Text(l10n.surveyLocationGps),
              icon: const Icon(AppIcons.myLocation, size: 18),
            ),
            ButtonSegment(
              value: _LocationChoice.manual,
              label: Text(l10n.surveyLocationManual),
              icon: const Icon(AppIcons.editLocationAlt, size: 18),
            ),
            ButtonSegment(
              value: _LocationChoice.skip,
              label: Text(l10n.surveyLocationSkip),
              icon: const Icon(AppIcons.locationOff, size: 18),
            ),
          ],
          selected: {locationChoice},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            HapticFeedback.selectionClick();
            onLocationChoiceChanged(selection.first);
          },
        ),
        const SizedBox(height: 12),
        if (locationChoice == _LocationChoice.gps) ...[
          if (gpsFetching)
            Card(
              child: ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(l10n.pointCountLocationAcquiring),
              ),
            )
          else if (latitude != null && longitude != null)
            Card(
              child: ListTile(
                leading: const Icon(AppIcons.locationOn),
                title: Text(
                  '${latitude!.toStringAsFixed(4)}, '
                  '${longitude!.toStringAsFixed(4)}',
                ),
                trailing: IconButton(
                  icon: const Icon(AppIcons.refresh),
                  tooltip: l10n.pointCountLocationRefresh,
                  onPressed: onFetchGps,
                ),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(AppIcons.locationOff),
                title: Text(l10n.surveyLocationUnavailable),
                trailing: IconButton(
                  icon: const Icon(AppIcons.refresh),
                  tooltip: l10n.pointCountLocationRefresh,
                  onPressed: onFetchGps,
                ),
              ),
            ),
          const SizedBox(height: 8),
          WeatherSetupCard(
            latitude: latitude,
            longitude: longitude,
            locationUnavailableLabel: l10n.surveyLocationUnavailable,
          ),
        ],
        if (locationChoice == _LocationChoice.manual) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.surveyLatitude),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: lonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.surveyLongitude),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute<LatLng>(
                  builder: (_) => const MapPickerScreen(),
                ),
              );
              if (result != null) {
                onMapPick(result.latitude, result.longitude);
              }
            },
            icon: const Icon(AppIcons.map),
            label: Text(l10n.surveyPickOnMap),
          ),
          const SizedBox(height: 12),
          WeatherSetupCard(
            latitude: latitude,
            longitude: longitude,
            locationUnavailableLabel: l10n.surveyLocationUnavailable,
          ),
        ],
        if (locationChoice == _LocationChoice.skip) ...[
          Text(
            l10n.surveyLocationSkipNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 12),
          WeatherSetupCard(
            latitude: null,
            longitude: null,
            locationUnavailableLabel: l10n.surveyLocationUnavailable,
          ),
        ],
      ],
    );
  }
}

class _ParametersStep extends ConsumerWidget {
  const _ParametersStep({
    required this.recordingMode,
    required this.onRecordingModeChanged,
    required this.samplingMode,
    required this.onSamplingModeChanged,
    required this.topNPerSpecies,
    required this.onTopNPerSpeciesChanged,
    super.key,
  });

  final RecordingMode recordingMode;
  final ValueChanged<RecordingMode> onRecordingModeChanged;
  final SamplingMode samplingMode;
  final ValueChanged<SamplingMode> onSamplingModeChanged;
  final int topNPerSpecies;
  final ValueChanged<int> onTopNPerSpeciesChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final devicesAsync = ref.watch(inputDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    final inferenceRate = ref.watch(inferenceRateProvider);
    final confidenceThreshold = ref.watch(confidenceThresholdProvider);
    final sensitivity = ref.watch(sensitivityProvider);
    final recordingFormat = ref.watch(recordingFormatProvider);
    final clipContext = ref.watch(clipContextProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(
          l10n.surveyParametersTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Microphone input
        devicesAsync.when(
          loading:
              () => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.micRounded),
                title: Text(l10n.surveyMicrophone),
                trailing: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          error:
              (_, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.micRounded),
                title: Text(l10n.surveyMicrophone),
                subtitle: Text(l10n.surveyMicSystemDefault),
              ),
          data: (devices) {
            final label = _selectedDeviceLabel(
              l10n: l10n,
              devices: devices,
              selectedDevice: selectedDevice,
            );
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.micRounded),
              title: Text(l10n.surveyMicrophone),
              subtitle: Text(label),
              trailing: const Icon(AppIcons.chevronRight),
              onTap:
                  () => _showDevicePicker(
                    context,
                    ref,
                    l10n,
                    devices,
                    selectedDevice,
                  ),
            );
          },
        ),
        const Divider(height: 32),

        // Inference rate
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.speedRounded),
          title: Text(l10n.surveyInferenceRate),
          subtitle: Text('${inferenceRate.toStringAsFixed(2)} Hz'),
        ),
        Slider(
          value: inferenceRate,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          label: '${inferenceRate.toStringAsFixed(2)} Hz',
          onChanged: (v) => ref.read(inferenceRateProvider.notifier).set(v),
        ),

        // Confidence threshold
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.verifiedRounded),
          title: Text(l10n.settingsConfidenceThreshold),
          subtitle: Text('$confidenceThreshold %'),
        ),
        Slider(
          value: confidenceThreshold.toDouble(),
          min: 5,
          max: 90,
          divisions: 17,
          label: '$confidenceThreshold %',
          onChanged:
              (v) =>
                  ref.read(confidenceThresholdProvider.notifier).set(v.round()),
        ),

        // Sensitivity
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.hearing),
          title: Text(l10n.settingsSensitivity),
          subtitle: Text(sensitivity.toStringAsFixed(2)),
        ),
        Slider(
          value: sensitivity,
          min: 0.5,
          max: 1.5,
          divisions: 10,
          label: sensitivity.toStringAsFixed(2),
          onChanged: (v) => ref.read(sensitivityProvider.notifier).set(v),
        ),

        // Recording format (visible when recording is not off)
        if (recordingMode != RecordingMode.off) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.saveRounded),
            title: Text(l10n.settingsRecordingFormat),
            subtitle: Text(l10n.settingsHelpRecordingFormat),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'flac', label: Text('FLAC')),
                ButtonSegment(value: 'wav', label: Text('WAV')),
              ],
              selected: {recordingFormat == 'wav' ? 'wav' : 'flac'},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                HapticFeedback.selectionClick();
                ref.read(recordingFormatProvider.notifier).set(selection.first);
              },
            ),
          ),
        ],

        const Divider(height: 32),

        // Recording mode (segmented buttons)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.fiberManualRecordRounded),
          title: Text(l10n.surveyRecordingMode),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<RecordingMode>(
            segments: [
              ButtonSegment(
                value: RecordingMode.full,
                label: Text(l10n.surveyRecordingFull),
              ),
              ButtonSegment(
                value: RecordingMode.detectionsOnly,
                label: Text(l10n.surveyRecordingDetections),
              ),
              ButtonSegment(
                value: RecordingMode.off,
                label: Text(l10n.surveyRecordingOff),
              ),
            ],
            selected: {recordingMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              HapticFeedback.selectionClick();
              onRecordingModeChanged(selection.first);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Clip context (visible only when recording mode = detectionsOnly)
        if (recordingMode == RecordingMode.detectionsOnly) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.timerOutlined),
            title: Text(l10n.surveyClipContext),
            subtitle: Text(l10n.surveyClipContextDescription),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: clipContext.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              label: '±${clipContext}s',
              onChanged:
                  (v) => ref.read(clipContextProvider.notifier).set(v.round()),
            ),
          ),
        ],

        // Detection sampling (visible only when recording clips)
        if (recordingMode == RecordingMode.detectionsOnly) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.filterAltRounded),
            title: Text(l10n.surveyDetectionSampling),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<SamplingMode>(
              segments: [
                ButtonSegment(
                  value: SamplingMode.all,
                  label: Text(l10n.surveySamplingAll),
                ),
                ButtonSegment(
                  value: SamplingMode.topN,
                  label: Text(l10n.surveySamplingTopN),
                ),
                ButtonSegment(
                  value: SamplingMode.smart,
                  label: Text(l10n.surveySamplingSmart),
                ),
              ],
              selected: {samplingMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                HapticFeedback.selectionClick();
                onSamplingModeChanged(selection.first);
              },
            ),
          ),

          // Top N (visible only when sampling = topN or smart)
          if (samplingMode != SamplingMode.all) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.formatListNumberedRounded),
              title: Text(l10n.surveyTopNPerSpecies),
              subtitle: Text('$topNPerSpecies'),
            ),
            Slider(
              value: topNPerSpecies.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: '$topNPerSpecies',
              onChanged: (v) => onTopNPerSpeciesChanged(v.round()),
            ),
          ],
        ],
      ],
    );
  }
}

class _ScheduleStep extends ConsumerWidget {
  const _ScheduleStep({
    required this.cycleDuration,
    required this.repeatInterval,
    required this.scheduleEndMode,
    required this.scheduleEnd,
    required this.maxCycles,
    required this.lowBatteryStop,
    required this.dielPattern,
    required this.latitude,
    required this.longitude,
    required this.testCycleEnabled,
    required this.eachCycleIsSession,
    required this.onCycleDurationChanged,
    required this.onRepeatIntervalChanged,
    required this.onScheduleEndModeChanged,
    required this.onScheduleEndChanged,
    required this.onMaxCyclesChanged,
    required this.onLowBatteryStopChanged,
    required this.onDielPatternChanged,
    required this.onTestCycleEnabledChanged,
    required this.onEachCycleIsSessionChanged,
    super.key,
  });

  final Duration cycleDuration;
  final Duration repeatInterval;
  final _ScheduleEndMode scheduleEndMode;
  final DateTime scheduleEnd;
  final int maxCycles;
  final int lowBatteryStop;
  final AruDielPattern dielPattern;
  final double? latitude;
  final double? longitude;
  final bool testCycleEnabled;
  final bool eachCycleIsSession;
  final ValueChanged<Duration> onCycleDurationChanged;
  final ValueChanged<Duration> onRepeatIntervalChanged;
  final ValueChanged<_ScheduleEndMode> onScheduleEndModeChanged;
  final ValueChanged<DateTime> onScheduleEndChanged;
  final ValueChanged<int> onMaxCyclesChanged;
  final ValueChanged<int> onLowBatteryStopChanged;
  final ValueChanged<AruDielPattern> onDielPatternChanged;
  final ValueChanged<bool> onTestCycleEnabledChanged;
  final ValueChanged<bool> onEachCycleIsSessionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final repeatOptions =
        AruDefaults.repeatIntervalOptions
            .where((duration) => duration >= cycleDuration)
            .toList();
    final estimate = ref
        .watch(aruStorageEstimatorProvider)
        .estimate(
          AruStorageEstimateInput(
            schedule:
                AruDeploymentMetadata(
                  scheduleStart: DateTime.now(),
                  cycleDurationSeconds: cycleDuration.inSeconds,
                  repeatIntervalSeconds: repeatInterval.inSeconds,
                  scheduleEnd:
                      scheduleEndMode == _ScheduleEndMode.dateTime
                          ? scheduleEnd
                          : null,
                  maxCycles:
                      scheduleEndMode == _ScheduleEndMode.cycles
                          ? maxCycles
                          : null,
                  lowBatteryStopPercent:
                      lowBatteryStop > 0 ? lowBatteryStop : null,
                  dielPattern: dielPattern,
                  testCycleEnabled: testCycleEnabled,
                  latitude: latitude,
                  longitude: longitude,
                  recordingMode: RecordingMode.full.name,
                ).toScheduleConfig(),
            recordingMode: RecordingMode.full,
            format: ref.watch(recordingFormatProvider),
          ),
        );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(
          l10n.aruSetupSchedule,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _DurationSliderControl(
          label: l10n.aruCycleDuration,
          value: cycleDuration,
          options: AruDefaults.cycleDurationOptions,
          onChanged: onCycleDurationChanged,
        ),
        const SizedBox(height: 12),
        _DurationSliderControl(
          label: l10n.aruRepeatInterval,
          value:
              repeatOptions.contains(repeatInterval)
                  ? repeatInterval
                  : repeatOptions.first,
          options: repeatOptions,
          onChanged: onRepeatIntervalChanged,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(AppIcons.sdStorage),
            title: Text(l10n.aruStorageEstimate),
            subtitle: Text(
              estimate.hasFiniteTotal
                  ? _formatBytes(estimate.totalBytes ?? 0)
                  : '${l10n.aruPerDayEstimate}: ${_formatBytes(estimate.bytesPerScheduledDay)}',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.aruRecordingWindow,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AruDielPattern>(
          initialValue: dielPattern,
          decoration: const InputDecoration(),
          items: [
            for (final pattern in AruDielPattern.values)
              DropdownMenuItem(
                value: pattern,
                child: Row(
                  children: [
                    Icon(_dielPatternIcon(pattern), size: 18),
                    const SizedBox(width: 12),
                    Text(_dielPatternLabel(l10n, pattern)),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            HapticFeedback.selectionClick();
            onDielPatternChanged(value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _sunTimesSummary(
            l10n: l10n,
            date: DateTime.now(),
            latitude: latitude,
            longitude: longitude,
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.aruScheduleEnd,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SegmentedButton<_ScheduleEndMode>(
          segments: [
            ButtonSegment(
              value: _ScheduleEndMode.manual,
              label: Text(l10n.aruScheduleEndManual),
              icon: const Icon(AppIcons.stopRounded, size: 18),
            ),
            ButtonSegment(
              value: _ScheduleEndMode.cycles,
              label: Text(l10n.aruScheduleEndCycles),
              icon: const Icon(AppIcons.repeatRounded, size: 18),
            ),
            ButtonSegment(
              value: _ScheduleEndMode.dateTime,
              label: Text(l10n.aruScheduleEndDateTime),
              icon: const Icon(AppIcons.calendarTodayRounded, size: 18),
            ),
          ],
          selected: {scheduleEndMode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            HapticFeedback.selectionClick();
            onScheduleEndModeChanged(selection.first);
          },
        ),
        const SizedBox(height: 12),
        if (scheduleEndMode == _ScheduleEndMode.cycles) ...[
          Text('${l10n.aruMaxCycles}: $maxCycles'),
          Slider(
            value: maxCycles.toDouble(),
            min: 1,
            max: 72,
            divisions: 71,
            label: '$maxCycles',
            onChanged: (value) => onMaxCyclesChanged(value.round()),
          ),
        ] else if (scheduleEndMode == _ScheduleEndMode.dateTime) ...[
          OutlinedButton.icon(
            onPressed: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: scheduleEnd,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (pickedDate == null || !context.mounted) return;
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(scheduleEnd),
              );
              if (pickedTime == null) return;
              onScheduleEndChanged(
                DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                ),
              );
            },
            icon: const Icon(AppIcons.calendarTodayRounded),
            label: Text(DateFormat.yMMMd().add_jm().format(scheduleEnd)),
          ),
        ] else ...[
          Card(
            child: ListTile(
              leading: const Icon(AppIcons.scheduleRounded),
              title: Text(l10n.aruScheduleNoLimit),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('${l10n.aruLowBatteryStop}: $lowBatteryStop%'),
        Slider(
          value: lowBatteryStop.toDouble(),
          min: 0,
          max: 50,
          divisions: 10,
          label: '$lowBatteryStop%',
          onChanged: (value) => onLowBatteryStopChanged(value.round()),
        ),
        const Divider(height: 32),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(AppIcons.scienceRounded),
          title: Text(l10n.aruOptionalTestCycle),
          value: testCycleEnabled,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            onTestCycleEnabledChanged(value);
          },
        ),
        const Divider(height: 32),

        // Session Grouping
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(AppIcons.libraryBooks),
          title: Text(l10n.aruSessionGroupingEach),
          subtitle: Text(
            eachCycleIsSession
                ? l10n.aruSessionGroupingEachDesc
                : l10n.aruSessionGroupingAllDesc,
          ),
          value: eachCycleIsSession,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            onEachCycleIsSessionChanged(value);
          },
        ),
      ],
    );
  }
}

class _DurationSliderControl extends StatelessWidget {
  const _DurationSliderControl({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final Duration value;
  final List<Duration> options;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = options.indexOf(value).clamp(0, options.length - 1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                _formatDuration(options[index]),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: index.toDouble(),
            min: 0,
            max: (options.length - 1).toDouble(),
            divisions: options.length - 1,
            label: _formatDuration(options[index]),
            onChanged: (value) => onChanged(options[value.round()]),
          ),
        ],
      ),
    );
  }
}

class _FieldTipsStep extends StatelessWidget {
  const _FieldTipsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tips = [
      (AppIcons.airplaneTicket, l10n.aruReadyReminderAirplane),
      (AppIcons.batteryChargingFull, l10n.surveyTipBattery),
      (AppIcons.micExternalOnRounded, l10n.surveyTipMic),
      (AppIcons.air, l10n.surveyTipWind),
      (AppIcons.parkRounded, l10n.aruReadyReminderMount),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.surveyFieldTips,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...tips.map((tip) {
          final (icon, text) = tip;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ReadyStep extends ConsumerWidget {
  const _ReadyStep({
    required this.deploymentName,
    required this.stationId,
    required this.observerName,
    required this.latitude,
    required this.longitude,
    required this.cycleDuration,
    required this.repeatInterval,
    required this.scheduleEndMode,
    required this.scheduleEnd,
    required this.maxCycles,
    required this.lowBatteryStop,
    required this.dielPattern,
    required this.recordingMode,
    required this.samplingMode,
    required this.topNPerSpecies,
    required this.testCycleEnabled,
    required this.eachCycleIsSession,
    super.key,
  });

  final String deploymentName;
  final String stationId;
  final String observerName;
  final double? latitude;
  final double? longitude;
  final Duration cycleDuration;
  final Duration repeatInterval;
  final _ScheduleEndMode scheduleEndMode;
  final DateTime? scheduleEnd;
  final int? maxCycles;
  final int lowBatteryStop;
  final AruDielPattern dielPattern;
  final RecordingMode recordingMode;
  final SamplingMode samplingMode;
  final int topNPerSpecies;
  final bool testCycleEnabled;
  final bool eachCycleIsSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final devices = ref.watch(inputDevicesProvider).asData?.value ?? const [];
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final recordingFormat = ref.watch(recordingFormatProvider).toUpperCase();
    final estimate = ref
        .watch(aruStorageEstimatorProvider)
        .estimate(
          AruStorageEstimateInput(
            schedule:
                AruDeploymentMetadata(
                  scheduleStart: DateTime.now(),
                  cycleDurationSeconds: cycleDuration.inSeconds,
                  repeatIntervalSeconds: repeatInterval.inSeconds,
                  scheduleEnd: scheduleEnd,
                  maxCycles: maxCycles,
                  lowBatteryStopPercent:
                      lowBatteryStop > 0 ? lowBatteryStop : null,
                  dielPattern: dielPattern,
                  latitude: latitude,
                  longitude: longitude,
                  recordingMode: recordingMode.name,
                  samplingMode: samplingMode.name,
                  topNPerSpecies: topNPerSpecies,
                  testCycleEnabled: testCycleEnabled,
                ).toScheduleConfig(),
            recordingMode: recordingMode,
            format: ref.watch(recordingFormatProvider),
          ),
        );
    final micLabel = _selectedDeviceLabel(
      l10n: l10n,
      devices: devices,
      selectedDevice: selectedDevice,
    );
    final primaryStorage =
        estimate.hasFiniteTotal
            ? _formatBytes(estimate.totalBytes ?? 0)
            : _formatBytes(estimate.bytesPerScheduledDay);
    final primaryStorageLabel =
        estimate.hasFiniteTotal
            ? l10n.aruStorageEstimate
            : l10n.aruPerDayEstimate;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Icon(
          AppIcons.scheduleRounded,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(l10n.aruSetupReady, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(l10n.aruReadySummary),
        const SizedBox(height: 20),
        _ReviewCard(
          icon: AppIcons.landscapeRounded,
          title: l10n.aruSetupDetails,
          rows: [
            if (deploymentName.trim().isNotEmpty)
              (l10n.aruDeploymentName, deploymentName.trim()),
            if (stationId.trim().isNotEmpty)
              (l10n.aruStationId, stationId.trim()),
            if (observerName.trim().isNotEmpty)
              (l10n.aruObserverName, observerName.trim()),
            if (latitude == null || longitude == null)
              (l10n.surveyLocation, l10n.sessionNoLocation),
          ],
          footer:
              latitude != null && longitude != null
                  ? SiteContextCard(latitude: latitude!, longitude: longitude!)
                  : null,
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          icon: AppIcons.scheduleRounded,
          title: l10n.aruSetupSchedule,
          rows: [
            (l10n.aruCycleDuration, _formatDuration(cycleDuration)),
            (l10n.aruRepeatInterval, _formatDuration(repeatInterval)),
            (
              l10n.aruOptionalTestCycle,
              testCycleEnabled
                  ? _formatDuration(const Duration(minutes: 1))
                  : l10n.settingsFilterOff,
            ),
            (l10n.aruRecordingWindow, _dielPatternLabel(l10n, dielPattern)),
            (
              l10n.aruScheduleEnd,
              _scheduleEndSummary(
                l10n: l10n,
                mode: scheduleEndMode,
                scheduleEnd: scheduleEnd,
                maxCycles: maxCycles,
              ),
            ),
          ],
        ),
        if (testCycleEnabled) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(AppIcons.scienceRounded),
              title: Text(l10n.aruTestRun),
              subtitle: Text(l10n.aruTestRunReadyHint),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _ReviewCard(
          icon: AppIcons.micRounded,
          title: l10n.settingsAudio,
          rows: [
            (l10n.surveyMicrophone, micLabel),
            (l10n.settingsRecordingFormat, recordingFormat),
            (
              l10n.surveyRecordingMode,
              _recordingModeLabel(l10n, recordingMode),
            ),
            if (recordingMode == RecordingMode.detectionsOnly)
              (
                l10n.surveyDetectionSampling,
                _samplingModeLabel(l10n, samplingMode),
              ),
            if (recordingMode == RecordingMode.detectionsOnly &&
                samplingMode != SamplingMode.all)
              (l10n.surveyTopNPerSpecies, '$topNPerSpecies'),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          icon: AppIcons.sdStorage,
          title: l10n.aruStorageEstimate,
          rows: [
            (primaryStorageLabel, primaryStorage),
            (l10n.aruPerHourEstimate, _formatBytes(estimate.bytesPerHour)),
            (
              l10n.aruLowBatteryStop,
              lowBatteryStop > 0 ? '$lowBatteryStop%' : l10n.settingsFilterOff,
            ),
            (
              l10n.aruSessionGrouping,
              eachCycleIsSession
                  ? l10n.aruSessionGroupingEach
                  : l10n.aruSessionGroupingAll,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.icon,
    required this.title,
    required this.rows,
    this.footer,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final row in rows) _SummaryRow(label: row.$1, value: row.$2),
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

void _showDevicePicker(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  List<InputDeviceInfo> devices,
  String? selected,
) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder:
        (ctx) => SafeArea(
          child: RadioGroup<String?>(
            groupValue: selected,
            onChanged: (value) {
              ref.read(selectedDeviceProvider.notifier).state = value;
              Navigator.of(ctx).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l10n.surveyMicSelect,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                RadioListTile<String?>(
                  title: Text(l10n.surveyMicSystemDefault),
                  value: null,
                ),
                ...devices.map(
                  (device) => RadioListTile<String?>(
                    title: Text(
                      device.label.isEmpty ? device.id : device.label,
                    ),
                    value: device.id,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
  );
}

String _selectedDeviceLabel({
  required AppLocalizations l10n,
  required List<InputDeviceInfo> devices,
  required String? selectedDevice,
}) {
  if (selectedDevice == null) return l10n.surveyMicSystemDefault;
  return devices
          .where((device) => device.id == selectedDevice)
          .map((device) => device.label.isEmpty ? device.id : device.label)
          .firstOrNull ??
      selectedDevice;
}

String _recordingModeLabel(AppLocalizations l10n, RecordingMode mode) {
  return switch (mode) {
    RecordingMode.full => l10n.surveyRecordingFull,
    RecordingMode.detectionsOnly => l10n.surveyRecordingDetections,
    RecordingMode.off => l10n.surveyRecordingOff,
  };
}

String _samplingModeLabel(AppLocalizations l10n, SamplingMode mode) {
  return switch (mode) {
    SamplingMode.all => l10n.surveySamplingAll,
    SamplingMode.topN => l10n.surveySamplingTopN,
    SamplingMode.smart => l10n.surveySamplingSmart,
  };
}

String _dielPatternLabel(AppLocalizations l10n, AruDielPattern pattern) {
  return switch (pattern) {
    AruDielPattern.anyTime => l10n.aruDielAnyTime,
    AruDielPattern.dayOnly => l10n.aruDielDayOnly,
    AruDielPattern.nightOnly => l10n.aruDielNightOnly,
    AruDielPattern.aroundSunrise => l10n.aruDielAroundSunrise,
    AruDielPattern.aroundSunset => l10n.aruDielAroundSunset,
  };
}

IconData _dielPatternIcon(AruDielPattern pattern) {
  return switch (pattern) {
    AruDielPattern.anyTime => AppIcons.scheduleRounded,
    AruDielPattern.dayOnly => AppIcons.wbSunny,
    AruDielPattern.nightOnly => AppIcons.darkMode,
    AruDielPattern.aroundSunrise => AppIcons.wbTwilightRounded,
    AruDielPattern.aroundSunset => AppIcons.wbTwilightRounded,
  };
}

String _sunTimesSummary({
  required AppLocalizations l10n,
  required DateTime date,
  required double? latitude,
  required double? longitude,
}) {
  final sunTimes = estimateAruSunTimes(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );
  final formatter = DateFormat.jm();
  return l10n.aruSunTimesEstimate(
    formatter.format(sunTimes.sunrise),
    formatter.format(sunTimes.sunset),
  );
}

String _scheduleEndSummary({
  required AppLocalizations l10n,
  required _ScheduleEndMode mode,
  required DateTime? scheduleEnd,
  required int? maxCycles,
}) {
  return switch (mode) {
    _ScheduleEndMode.manual => l10n.aruScheduleEndManual,
    _ScheduleEndMode.cycles =>
      maxCycles != null
          ? l10n.aruCycleCount(maxCycles)
          : l10n.aruScheduleNoLimit,
    _ScheduleEndMode.dateTime when scheduleEnd != null => DateFormat.yMMMd()
        .add_jm()
        .format(scheduleEnd),
    _ => l10n.aruScheduleNoLimit,
  };
}

String _formatDuration(Duration duration) {
  if (duration.inHours >= 1 && duration.inMinutes % 60 == 0) {
    return '${duration.inHours} h';
  }
  if (duration.inHours >= 1) {
    return '${duration.inHours} h ${duration.inMinutes % 60} min';
  }
  if (duration.inMinutes >= 1) {
    return '${duration.inMinutes} min';
  }
  return '${duration.inSeconds} s';
}

String _formatBytes(int bytes) {
  const mb = 1024 * 1024;
  const gb = 1024 * mb;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  return '${(bytes / mb).toStringAsFixed(0)} MB';
}
