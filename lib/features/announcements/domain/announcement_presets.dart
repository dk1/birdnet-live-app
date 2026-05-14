// =============================================================================
// AnnouncementPresets
// =============================================================================
//
// The two user-facing knobs (§3 intro of dev/announcements.md):
//
//   • Verbosity  — minimal | balanced (default) | chatty | custom
//   • Frequency  — sparse  | normal   (default) | frequent | custom
//
// Each preset stamps a fixed set of Advanced numerics into shared
// preferences in one transaction. The settings layer is responsible
// for the write; this file only owns the *profiles* (the value tables)
// and the parse/format helpers so every part of the codebase agrees on
// what a preset means.
//
// `custom` is never picked by the wizard — it appears only as the
// downgrade target when the user manually edits an Advanced numeric
// and we need to stop claiming a named preset is in effect.
// =============================================================================

/// How talkative the phrasing engine should be inside a bucket. See the
/// file header and §3 of dev/announcements.md.
enum AnnouncementVerbosity { minimal, balanced, chatty, custom }

/// How often the controller is allowed to speak. Maps to the throttling
/// constants below via [FrequencyProfile].
enum AnnouncementFrequency { sparse, normal, frequent, custom }

/// Round-trip safe enum parsing — used by the providers to decode the
/// string-backed pref values. Anything unrecognized falls back to the
/// default ([AnnouncementVerbosity.balanced]) so a corrupted pref never
/// crashes startup.
AnnouncementVerbosity parseVerbosity(String? raw) {
  for (final v in AnnouncementVerbosity.values) {
    if (v.name == raw) return v;
  }
  return AnnouncementVerbosity.balanced;
}

/// Round-trip safe enum parsing for [AnnouncementFrequency]. Defaults
/// to [AnnouncementFrequency.normal].
AnnouncementFrequency parseFrequency(String? raw) {
  for (final f in AnnouncementFrequency.values) {
    if (f.name == raw) return f;
  }
  return AnnouncementFrequency.normal;
}

/// The numeric throttling constants a frequency preset stamps into
/// shared preferences. All values are seconds except [maxPerMinute].
///
/// The two routing-mode-specific overrides ([minIntervalSecondsSpeaker]
/// and [maxPerMinuteSpeaker]) are applied at *runtime* by the
/// controller when it detects it is speaking through the built-in
/// speaker — they are NOT separate prefs. This keeps the Settings
/// surface to one number per knob.
class FrequencyProfile {
  final int startupGraceSeconds;
  final int minIntervalSeconds;
  final int minIntervalSecondsSpeaker;
  final int maxPerMinute;
  final int maxPerMinuteSpeaker;
  final int streakSilenceSeconds;
  final int recencyResetSeconds;
  final int sessionResetSeconds;
  final int coalesceWindowSeconds;

  const FrequencyProfile({
    required this.startupGraceSeconds,
    required this.minIntervalSeconds,
    required this.minIntervalSecondsSpeaker,
    required this.maxPerMinute,
    required this.maxPerMinuteSpeaker,
    required this.streakSilenceSeconds,
    required this.recencyResetSeconds,
    required this.sessionResetSeconds,
    required this.coalesceWindowSeconds,
  });
}

/// Profile lookup. The `normal` profile is the §5.2 baseline; `sparse`
/// roughly halves the cadence for survey use; `frequent` roughly
/// doubles it for short Live sessions.
const Map<AnnouncementFrequency, FrequencyProfile> kFrequencyProfiles = {
  AnnouncementFrequency.sparse: FrequencyProfile(
    startupGraceSeconds: 60,
    minIntervalSeconds: 30,
    minIntervalSecondsSpeaker: 45,
    maxPerMinute: 2,
    maxPerMinuteSpeaker: 2,
    streakSilenceSeconds: 180,
    recencyResetSeconds: 300,
    sessionResetSeconds: 1800,
    coalesceWindowSeconds: 5,
  ),
  AnnouncementFrequency.normal: FrequencyProfile(
    startupGraceSeconds: 30,
    minIntervalSeconds: 8,
    minIntervalSecondsSpeaker: 12,
    maxPerMinute: 6,
    maxPerMinuteSpeaker: 4,
    streakSilenceSeconds: 45,
    recencyResetSeconds: 120,
    sessionResetSeconds: 900,
    coalesceWindowSeconds: 3,
  ),
  AnnouncementFrequency.frequent: FrequencyProfile(
    startupGraceSeconds: 10,
    minIntervalSeconds: 4,
    minIntervalSecondsSpeaker: 8,
    maxPerMinute: 12,
    maxPerMinuteSpeaker: 6,
    streakSilenceSeconds: 25,
    recencyResetSeconds: 90,
    sessionResetSeconds: 600,
    coalesceWindowSeconds: 2,
  ),
};

/// Profile for the [AnnouncementFrequency.custom] sentinel: returns
/// `null`, signalling to callers that they should keep whatever values
/// are currently in shared preferences instead of overwriting them.
FrequencyProfile? frequencyProfileFor(AnnouncementFrequency f) {
  return kFrequencyProfiles[f];
}
