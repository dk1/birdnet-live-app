// =============================================================================
// geoCommonnessProvider
// =============================================================================
//
// Per-species "how common is this here right now" + "is it in season"
// derived from the geo-model. Consumed by the Announcements pipeline
// to attach a `CommonnessBin` and an `isOutOfSeason` flag to each
// detection so the Chatty engine can append a one-line phrase like
// *"A common bird in your area at this time of year."* or *"A bit of a
// rarity around here — and not usually around this time of year."*
//
// Why this lives in the announcements feature (and not in `explore/`):
//
//   * The Explore screen already calls [GeoModel.predictAllWeeks] via
//     [exploreSpeciesProvider], but its output is *normalised* (top
//     species at the location forced to 100.0). Announcements need the
//     *raw* geo scores so we can compute per-species seasonality
//     (current vs. annual peak) — the normalised series throws that
//     information away.
//   * Keeping the commonness derivation here lets the Explore feature
//     evolve independently and avoids loading the geo data twice when
//     a user has only the Live screen open.
//
// Cost: one [GeoModel.predictAllWeeks] call (48 single-sample model
// runs of the small geo-model — milliseconds total). Cached by Riverpod
// per (location, week) tuple via the dependency on
// [currentLocationProvider]; recomputed only when the user moves.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../explore/explore_providers.dart';
import '../explore/explore_tier.dart';
import '../inference/geo_model.dart';
import 'domain/announcement_signals.dart';

/// Per-species commonness/season summary used by the announcement
/// pipeline. `currentScore` is kept around for tests / future tweaks
/// even though the engine only consumes the derived bins.
class GeoCommonnessEntry {
  /// Coarse "how common is this species here this week" bucket.
  final CommonnessBin commonness;

  /// `true` when current week's probability is well below the species'
  /// annual maximum at this location — i.e. a migrant caught outside
  /// its peak window. Threshold: current/annualMax < 0.4.
  final bool isOutOfSeason;

  /// Raw current-week geo-model score. Diagnostic only.
  final double currentScore;

  /// Species' annual peak score across all 48 weeks at this location.
  /// Diagnostic only.
  final double annualMax;

  const GeoCommonnessEntry({
    required this.commonness,
    required this.isOutOfSeason,
    required this.currentScore,
    required this.annualMax,
  });
}

/// Map of `scientificName` → [GeoCommonnessEntry] for the user's
/// current location. Returns `null` (not an empty map) when the
/// geo-model isn't ready or no location is available, so callers can
/// distinguish "skip the addendum" from "every species is rare".
///
/// The commonness bin is the species' abundance tier under the same
/// distribution-adaptive scale the Explore screen uses ([ExploreTierScale]),
/// built over the same audio-detectable population, so the spoken hint and
/// the Explore card agree. The rank-relative scale keeps it meaningful
/// across regions of wildly different absolute geo-scores (tropics vs.
/// Arctic).
final geoCommonnessProvider = FutureProvider<Map<String, GeoCommonnessEntry>?>((
  ref,
) async {
  final location = await ref.watch(currentLocationProvider.future);
  final geoModel = await ref.watch(geoModelProvider.future);
  final audioLabels = await ref.watch(audioLabelsSetProvider.future);
  if (location == null) return null;

  final week = GeoModel.dateTimeToWeek(DateTime.now());
  final allWeeks = await geoModel.predictAllWeeks(
    latitude: location.latitude,
    longitude: location.longitude,
  );

  // Build the *same* distribution-adaptive abundance scale the Explore
  // screen uses, from the *same* population: audio-detectable species
  // scoring above Explore's inclusion threshold for the current week (see
  // `exploreSpeciesProvider`). Matching the population is what makes a
  // spoken commonness hint agree with the tier shown on that bird's
  // Explore card, rather than drifting from it.
  const kExploreInclusionThreshold = 0.03;
  final scaleScores = <double>[];
  for (final entry in allWeeks.entries) {
    if (!audioLabels.contains(entry.key)) continue;
    final current = entry.value[week - 1];
    if (current < kExploreInclusionThreshold) continue;
    scaleScores.add(current);
  }
  if (scaleScores.isEmpty) return const {};
  final tierScale = ExploreTierScale.fromScores(scaleScores);

  final out = <String, GeoCommonnessEntry>{};
  for (final entry in allWeeks.entries) {
    // Only species the audio model can detect can ever be announced, so
    // there's no point classifying the geo-only remainder.
    if (!audioLabels.contains(entry.key)) continue;
    final scores = entry.value;
    final current = scores[week - 1];
    var annualMax = 0.0;
    for (final s in scores) {
      if (s > annualMax) annualMax = s;
    }
    final bin = _commonnessBinForTier(tierScale.tierFor(current));
    // Out of season: well below annual peak, and the peak is high
    // enough to be a meaningful comparison. Skip the seasonal
    // signal entirely for species whose annual maximum at this
    // location is itself near zero — those are vagrants, not
    // migrants, and the "off-season" framing would be misleading.
    final isOff =
        annualMax > 0.05 && current > 0 && (current / annualMax) < 0.4;
    out[entry.key] = GeoCommonnessEntry(
      commonness: bin,
      isOutOfSeason: isOff,
      currentScore: current,
      annualMax: annualMax,
    );
  }
  return out;
});

/// 1:1 map from an Explore abundance tier to the announcement's
/// [CommonnessBin]. They share the same six semantic levels; keeping the
/// enums separate lets the phrasing engine stay a pure-Dart library.
CommonnessBin _commonnessBinForTier(ExploreTier tier) {
  switch (tier) {
    case ExploreTier.abundant:
      return CommonnessBin.abundant;
    case ExploreTier.common:
      return CommonnessBin.common;
    case ExploreTier.frequent:
      return CommonnessBin.frequent;
    case ExploreTier.uncommon:
      return CommonnessBin.uncommon;
    case ExploreTier.scarce:
      return CommonnessBin.scarce;
    case ExploreTier.rare:
      return CommonnessBin.rare;
  }
}
