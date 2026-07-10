// =============================================================================
// AnnouncementSignals
// =============================================================================
//
// Per-detection input to the phrasing engine's bucket selector.
// The four signals (§3.1 of dev/announcements.md) are kept deliberately
// simple — three confidence bins, recency / frequency / streak as plain
// counts and seconds — so the bucket logic is a pure function over a
// tiny value type and trivially unit-testable.
//
// This file has zero Flutter / async / I/O imports on purpose; the
// engine that consumes these values is a pure-Dart library that can
// run in any isolate (audio worker, tests, batch tools).
// =============================================================================

/// Coarse confidence bucket derived from the raw model score.
///
/// Thresholds (§3.2): high ≥ 0.80, medium 0.55–0.80, low < 0.55.
/// Detections below the user's species-filter floor never reach the
/// engine in the first place, so [low] still represents a legitimate,
/// user-allowed detection — just one we should hedge about.
enum ConfidenceBin { low, medium, high }

/// Convenience: map a raw 0–1 score to a [ConfidenceBin] using the
/// project-wide cutoffs from §3.2. Centralised here so bucket selection
/// and any UI badges stay in lockstep.
ConfidenceBin confidenceBinFor(double score) {
  if (score >= 0.80) return ConfidenceBin.high;
  if (score >= 0.55) return ConfidenceBin.medium;
  return ConfidenceBin.low;
}

/// How common a species is at the user's location *right now*. Used by
/// Chatty verbosity to add a single first-announcement phrase like
/// *"A common bird in your area"* / *"A bit of a rarity around here."*
///
/// These six bins mirror the Explore screen's abundance tiers exactly
/// (`ExploreTier` / `ExploreTierScale`) so the spoken hint matches the
/// tier the user sees on the Explore card for the same bird — a species
/// shown as *Frequent* in Explore gets a "regular around here" nudge, not
/// an "uncommon" one. The classification is done in
/// `geo_commonness_provider.dart` from the *same* distribution-adaptive
/// scale Explore builds (over the same audio-detectable population); this
/// enum stays Flutter-free so the phrasing engine remains a pure-Dart
/// library and doesn't import the Explore widget layer.
///
/// Ordered ascending by abundance so `.index` is an ordinal rank
/// (0 = rare … 5 = abundant), matching `ExploreTier`.
enum CommonnessBin { rare, scarce, uncommon, frequent, common, abundant }

/// Everything the phrasing engine needs to pick a bucket for a single
/// detection.
///
/// Built by the alert-sink layer from the live detection plus the
/// per-species bookkeeping the engine maintains (last-seen timestamp,
/// session-wide count, current streak). Treat instances as immutable
/// snapshots — the engine never mutates them.
class AnnouncementSignals {
  /// Coarse confidence bin (see [confidenceBinFor]).
  final ConfidenceBin confidence;

  /// `true` if this species has *not* been heard for at least
  /// [recencyResetSeconds]. The phrasing engine uses this to choose
  /// between "fresh" buckets (A / D / F) and "again" buckets (B / E / G).
  final bool isRecent;

  /// `true` if this is the very first time the species shows up in the
  /// current session. Drives the optional Chatty addendum
  /// ("first one today.") and the first-in-session trigger mode.
  final bool isFirstInSession;

  /// Number of consecutive detections of *this same species* with gaps
  /// shorter than `streakSilenceSeconds` (§3.4). A streak of 1 is the
  /// initial detection; ≥ 2 routes the engine into Bucket C / "still
  /// calling" territory rather than re-announcing the same bird.
  final int streakLength;

  /// `true` if this is the very first time the species is being
  /// **spoken** in the current session. Distinct from
  /// [isFirstInSession] (which only tracks whether the species has
  /// been *seen*): a species can be seen for many cycles but throttled
  /// out, and this flag stays `true` until the announcement actually
  /// fires for the first time. Drives the optional Chatty
  /// commonness/season tag-on (*"A common bird in your area at this
  /// time of year."*).
  final bool isFirstAnnouncement;

  /// Coarse "how common is this species here right now" bucket from
  /// the geo-model. `null` when no location is available, the
  /// geo-model isn't loaded yet, or the species is missing from the
  /// geo-model labels. The phrasing engine omits the commonness
  /// addendum when this is null.
  final CommonnessBin? commonness;

  /// `true` when the species is currently outside its annual peak at
  /// this location — specifically, when `currentWeekScore /
  /// annualMaxScore < 0.4` *and* the current score is high enough for
  /// the comparison to be meaningful (commonness is not
  /// [CommonnessBin.rare]). Used by the Chatty engine to optionally
  /// append a "...not usually here this time of year" tail for migrant
  /// birds caught outside their normal window.
  final bool isOutOfSeason;

  const AnnouncementSignals({
    required this.confidence,
    required this.isRecent,
    required this.isFirstInSession,
    required this.streakLength,
    this.isFirstAnnouncement = false,
    this.commonness,
    this.isOutOfSeason = false,
  });
}
