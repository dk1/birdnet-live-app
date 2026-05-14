// =============================================================================
// PhrasingEngine
// =============================================================================
//
// Turns a detection (or a coalesced batch) into a string the TTS layer
// can speak. Pure Dart, no Flutter, no async, no I/O — the
// [TemplateLibrary] does the loading and hands a ready [TemplateBundle]
// to the engine at construction time.
//
// Responsibilities (§3 of dev/announcements.md):
//
//   • Bucket selection delegated to [selectBucket] / [selectCoalesceBucket].
//   • Verbosity-aware template *picking*:
//       - minimal → speak just "{name}." (templates bypassed entirely).
//       - balanced → uniform pick from the bucket's balanced list.
//       - chatty   → uniform pick from the bucket's chatty list, falling
//                    back to balanced when chatty is empty (handled by
//                    the bundle, see TemplateLibrary).
//   • Anti-repeat: a 3-slot ring buffer per bucket so the same template
//     can't fire three times in a row even if the picker happens to
//     prefer it (§3.5).
//   • Locale fallback: handled at the TemplateLibrary layer; if the
//     active bundle is empty for a bucket the engine speaks the bare
//     name as a graceful last-resort.
// =============================================================================

import 'dart:math';

import '../domain/announcement_buckets.dart';
import '../domain/announcement_presets.dart';
import '../domain/announcement_signals.dart';
import 'template_library.dart';

/// Maximum number of recently-used template indices remembered per
/// bucket for anti-repeat. Three matches the §3.5 spec.
const int _antiRepeatHistory = 3;

class PhrasingEngine {
  final TemplateBundle _bundle;
  final Random _random;

  /// Per-bucket ring buffer of recently-used indices. Bounded to
  /// [_antiRepeatHistory] entries; oldest entry is dropped on push.
  final Map<AnnouncementBucket, List<int>> _recent = {};

  PhrasingEngine({required TemplateBundle bundle, Random? random})
    : _bundle = bundle,
      _random = random ?? Random();

  /// Speak a single-species detection. Returns the rendered string,
  /// e.g. *"There's a Robin calling."*
  ///
  /// [name] is the localized common name (already in the user's
  /// species-language preference). The engine never touches taxonomy.
  String speakOne({
    required String name,
    required AnnouncementSignals signals,
    required AnnouncementVerbosity verbosity,
  }) {
    if (verbosity == AnnouncementVerbosity.minimal) {
      return '$name.';
    }
    final bucket = selectBucket(signals);
    final template = _pickTemplate(bucket, verbosity);
    if (template == null) return '$name.';
    return template.replaceAll('{name}', name);
  }

  /// Speak a coalesced multi-species batch. [names] should already be
  /// trimmed / deduped by the caller; the first three names slot into
  /// `{name1}` / `{name2}` / `{name3}` and any remainder is implicitly
  /// summarised by the H_many template ("…and a few more.").
  ///
  /// Falls back to a plain comma-joined list if no template is
  /// available (defensive — only happens with a corrupted bundle).
  String speakMany({
    required List<String> names,
    required AnnouncementVerbosity verbosity,
  }) {
    if (names.isEmpty) return '';
    if (names.length == 1) {
      return verbosity == AnnouncementVerbosity.minimal
          ? '${names.first}.'
          : '${names.first}.';
    }
    // Two-name batches don't fit the H_three / H_many templates (which
    // hard-code three {name*} slots). Speaking them through those
    // templates would either drop a name or leave a literal empty slot
    // ("…A, B, and ."). Render them as a plain comma list instead;
    // the locale-specific conjunction ("and" / "und" / "et") is left
    // out on purpose so this fallback works in every locale without
    // pulling in a translation table.
    if (names.length == 2) {
      return '${names[0]}, ${names[1]}.';
    }
    final bucket = selectCoalesceBucket(names.length);
    if (verbosity == AnnouncementVerbosity.minimal) {
      // Minimal mode never hedges; just list the names.
      return '${names.take(3).join(', ')}.';
    }
    final template = _pickTemplate(bucket, verbosity);
    if (template == null) {
      return '${names.take(3).join(', ')}.';
    }
    // names.length is guaranteed ≥ 3 here, so name1/name2/name3 are
    // always populated; the padding is defensive only.
    final picks = names.take(3).toList();
    return template
        .replaceAll('{name1}', picks[0])
        .replaceAll('{name2}', picks[1])
        .replaceAll('{name3}', picks[2]);
  }

  /// Reset the per-bucket anti-repeat memory. Called at session start
  /// and from the unit tests.
  void reset() => _recent.clear();

  String? _pickTemplate(
    AnnouncementBucket bucket,
    AnnouncementVerbosity verbosity,
  ) {
    final variants = _bundle.variantsFor(bucket, verbosity);
    if (variants.isEmpty) return null;
    final history = _recent.putIfAbsent(bucket, () => <int>[]);
    final candidates = <int>[];
    for (var i = 0; i < variants.length; i++) {
      if (!history.contains(i)) candidates.add(i);
    }
    // If every variant is in the history (small lists ≤ 3), allow
    // anything except the most-recent one. If the bucket has only one
    // variant we can do nothing about repetition — speak it anyway.
    final pool =
        candidates.isNotEmpty
            ? candidates
            : (variants.length > 1
                ? [
                  for (var i = 0; i < variants.length; i++)
                    if (i != history.last) i,
                ]
                : [0]);
    final picked = pool[_random.nextInt(pool.length)];
    history.add(picked);
    if (history.length > _antiRepeatHistory) history.removeAt(0);
    return variants[picked];
  }
}
