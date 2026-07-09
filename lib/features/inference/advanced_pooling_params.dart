// =============================================================================
// Advanced Pooling Params — runtime overrides for the temporal-pooling gate
// =============================================================================
//
// Bundles the "advanced" temporal-pooling knobs that are normally baked into
// the model config (`temporalPooling` in `model_config.json`) so they can be
// tuned live from the Settings screen without touching the asset. Each field
// is nullable: `null` means "leave the model-config default in place".
//
// This is a transport object. It is threaded from the composed
// `advancedPoolingParamsProvider` through the mode controllers into
// [InferenceService.applyAdvancedPoolingParams]. The basic pooling knobs
// (mode / windows / time gate) keep their own dedicated setters — see
// [InferenceService.setPoolingMode] etc.
// =============================================================================

import 'package:flutter/foundation.dart';

/// Immutable snapshot of the advanced temporal-pooling overrides.
@immutable
class AdvancedPoolingParams {
  const AdvancedPoolingParams({
    this.alpha,
    this.minSupportWindows,
    this.supportThresholdFraction,
    this.supportThresholdFloor,
    this.veryHighImmediateThreshold,
  });

  /// LME alpha — higher values weight recent peaks more heavily.
  final double? alpha;

  /// Number of recent windows that must clear the support threshold before a
  /// new LME/adaptive detection is allowed through the gate. `1` disables the
  /// gate.
  final int? minSupportWindows;

  /// Fraction of the active confidence threshold used as the per-window
  /// support threshold (before the floor is applied).
  final double? supportThresholdFraction;

  /// Lower bound on the per-window support threshold.
  final double? supportThresholdFloor;

  /// Raw current-window score high enough to bypass multi-window support.
  final double? veryHighImmediateThreshold;

  /// All-`null` bundle — applies no overrides (model-config defaults win).
  static const AdvancedPoolingParams none = AdvancedPoolingParams();

  @override
  bool operator ==(Object other) =>
      other is AdvancedPoolingParams &&
      other.alpha == alpha &&
      other.minSupportWindows == minSupportWindows &&
      other.supportThresholdFraction == supportThresholdFraction &&
      other.supportThresholdFloor == supportThresholdFloor &&
      other.veryHighImmediateThreshold == veryHighImmediateThreshold;

  @override
  int get hashCode => Object.hash(
    alpha,
    minSupportWindows,
    supportThresholdFraction,
    supportThresholdFloor,
    veryHighImmediateThreshold,
  );

  @override
  String toString() =>
      'AdvancedPoolingParams(alpha: $alpha, minSupportWindows: '
      '$minSupportWindows, supportThresholdFraction: $supportThresholdFraction, '
      'supportThresholdFloor: $supportThresholdFloor, '
      'veryHighImmediateThreshold: $veryHighImmediateThreshold)';
}
