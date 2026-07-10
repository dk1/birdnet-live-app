// =============================================================================
// Survey Alert Coordinator — Glue between detections and notifications
// =============================================================================
//
// Owns the per-survey alert state and wires:
//
//   detection → SurveyAlertEngine → AlertThrottler → SpeciesAlertNotifier
//
// plus a periodic flush timer that drains coalesced summaries and a callback
// that lets the live UI mirror alerts as in-app toasts.
//
// The coordinator is constructed once at the start of a survey, fed every
// new detection record, and shut down at the end. All policy lives here
// rather than in `SurveyController` so the controller can stay focused on
// the audio/inference pipeline.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/services/ntfy_service.dart';
import '../history/global_species_history.dart';
import '../live/live_session.dart' show DetectionRecord;
import 'alert_throttler.dart';
import 'species_alert_notifier.dart';
import 'survey_alert_engine.dart';

/// Surfaced to the UI when an alert is delivered (so the live screen can
/// also show an in-app toast). `null` for queued / suppressed alerts.
typedef AlertDeliveredCallback =
    void Function(AlertCandidate? one, SummaryAlert? summary);

class SurveyAlertCoordinator {
  SurveyAlertCoordinator({
    required this.mode,
    required this.notifier,
    required this.notifierStrings,
    required this.globalHistory,
    required this.geoScores,
    required this.watchlist,
    this.lifeList,
    this.ntfyTopic,
    this.minConfidence = 0.5,
    this.rareThreshold = 0.05,
    this.startupGraceSeconds = 60,
    this.minIntervalSeconds = 15,
    this.maxPerMinute = 3,
    this.coalesce = true,
    this.inAppToast = true,
    this.onDelivered,
    this.nameLocalizer,
    DateTime Function()? clock,
    Duration tickInterval = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now {
    _engine = SurveyAlertEngine(
      mode: mode,
      globalHistory: globalHistory,
      geoScores: geoScores ?? const <String, double>{},
      watchlist: watchlist ?? const <String>{},
      lifeList: lifeList ?? const <String>{},
      minConfidence: minConfidence,
      rareThreshold: rareThreshold,
    );
    _throttler = AlertThrottler(
      surveyStart: _clock(),
      startupGrace: Duration(seconds: startupGraceSeconds),
      minInterval: Duration(seconds: minIntervalSeconds),
      maxPerMinute: maxPerMinute,
      coalesce: coalesce,
      bypassReasons: const {
        AlertReason.rare,
        AlertReason.watchlist,
        AlertReason.lifer,
      },
      now: _clock,
    );
    _tickTimer = Timer.periodic(tickInterval, (_) => _tick());
  }

  final AlertMode mode;
  final SpeciesAlertNotifier notifier;
  final SpeciesAlertStrings notifierStrings;
  final GlobalSpeciesHistory globalHistory;
  final Map<String, double>? geoScores;
  final Set<String>? watchlist;

  /// Scientific names on the user's imported eBird life list, used by
  /// [AlertMode.lifer].
  final Set<String>? lifeList;

  /// ntfy.sh topic to push lifer alerts to, in addition to the local
  /// notification (local-only, throwaway — not part of the upstream eBird
  /// PR). Null or empty disables the push.
  final String? ntfyTopic;

  final double minConfidence;
  final double rareThreshold;
  final int startupGraceSeconds;
  final int minIntervalSeconds;
  final int maxPerMinute;
  final bool coalesce;
  final bool inAppToast;
  final AlertDeliveredCallback? onDelivered;

  /// Optional mapper from `(scientificName, fallbackCommonName)` to the
  /// user's preferred localized common name. When null, the original
  /// English common name from the detection is used.
  final String Function(String sciName, String fallback)? nameLocalizer;

  late final SurveyAlertEngine _engine;
  late final AlertThrottler _throttler;
  Timer? _tickTimer;
  final DateTime Function() _clock;
  final Set<String> _sessionSpeciesSeen = <String>{};

  /// Local-only, throwaway: lets [AlertMode.lifer] re-fire for a species
  /// already alerted this session, once [_liferReAlertCooldown] has passed
  /// since its last alert — unlike every other mode, which alerts a given
  /// species at most once per survey. Not part of the upstream eBird PR.
  final Map<String, DateTime> _lastLiferAlertAt = <String, DateTime>{};
  static const Duration _liferReAlertCooldown = Duration(minutes: 10);

  /// Whether a future user-visible alert is even theoretically possible.
  bool get isActive => mode != AlertMode.off && _tickTimer != null;

  /// Feed a freshly-added detection into the alert pipeline.
  ///
  /// Returns immediately; notifications fire on a microtask.
  void onDetection(DetectionRecord record) {
    if (mode == AlertMode.off) return;
    final name = record.scientificName;
    final isFirstEverThisSession = _sessionSpeciesSeen.add(name);
    final firstInSession =
        mode == AlertMode.lifer
            ? _liferEligibleToFire(name)
            : isFirstEverThisSession;
    final candidate = _engine.evaluate(record, firstInSession: firstInSession);
    if (candidate == null) return;

    // Persist global-history hit *before* delivering — that way a crash
    // mid-notification won't cause the same species to fire again on
    // restart for first-ever mode.
    if (candidate.reason == AlertReason.firstEver) {
      // Fire-and-forget: we've already added it to the in-memory set
      // inside [SurveyAlertEngine] via `globalHistory.add`.
      unawaited(globalHistory.add(name));
    }

    // Local-only, throwaway: a lifer re-alert (same species, heard again
    // after the cooldown) pushes to ntfy only — no local notification, no
    // throttle/coalesce. Not part of the upstream eBird PR.
    if (mode == AlertMode.lifer && !isFirstEverThisSession) {
      _pushLiferIfNeeded(candidate);
      return;
    }

    final decision = _throttler.admit(candidate);
    switch (decision) {
      case DeliverNow(:final alert):
        unawaited(_deliverOne(alert));
      case Coalesce():
        // Will be flushed on the next tick if conditions allow.
        break;
      case Suppress():
        break;
    }
  }

  /// Tear down timers and force-flush any queued alerts as a final
  /// summary.  Safe to call multiple times.
  Future<void> shutdown({bool flushFinal = true}) async {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (flushFinal) {
      final summary = _throttler.tick(force: true);
      if (summary != null) {
        await _deliverSummary(summary);
      }
    }
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /// Local-only, throwaway: true the first time [name] is heard, or again
  /// once [_liferReAlertCooldown] has elapsed since its last alert.
  bool _liferEligibleToFire(String name) {
    final now = _clock();
    final lastAlert = _lastLiferAlertAt[name];
    if (lastAlert != null && now.difference(lastAlert) < _liferReAlertCooldown) {
      return false;
    }
    _lastLiferAlertAt[name] = now;
    return true;
  }

  void _tick() {
    final summary = _throttler.tick();
    if (summary != null) {
      unawaited(_deliverSummary(summary));
    }
  }

  Future<void> _deliverOne(AlertCandidate alert) async {
    final localized = _localize(alert);
    try {
      await notifier.notifyOne(localized, strings: notifierStrings);
    } catch (e) {
      debugPrint('[SurveyAlertCoordinator] notifyOne failed: $e');
    }
    _pushLiferIfNeeded(localized);
    if (inAppToast) {
      onDelivered?.call(localized, null);
    }
  }

  Future<void> _deliverSummary(SummaryAlert summary) async {
    final localized =
        nameLocalizer == null
            ? summary
            : SummaryAlert(
              alerts: summary.alerts.map(_localize).toList(growable: false),
            );
    try {
      await notifier.notifySummary(localized, strings: notifierStrings);
    } catch (e) {
      debugPrint('[SurveyAlertCoordinator] notifySummary failed: $e');
    }
    for (final alert in localized.alerts) {
      _pushLiferIfNeeded(alert);
    }
    if (inAppToast) {
      onDelivered?.call(null, localized);
    }
  }

  AlertCandidate _localize(AlertCandidate a) {
    if (nameLocalizer == null) return a;
    final name = nameLocalizer!(a.scientificName, a.commonName);
    if (name == a.commonName) return a;
    return a.copyWith(commonName: name);
  }

  /// Fires an ntfy.sh push for lifer alerts, in addition to the local
  /// notification (local-only, throwaway — not part of the upstream eBird
  /// PR).
  void _pushLiferIfNeeded(AlertCandidate alert) {
    if (alert.reason != AlertReason.lifer) return;
    final topic = ntfyTopic;
    if (topic == null || topic.trim().isEmpty) return;
    unawaited(
      NtfyService.send(
        topic: topic,
        title: 'New Lifer',
        message: '${alert.commonName} detected',
      ),
    );
  }
}
