import 'dart:typed_data';
import 'dart:ui' show Color;

// =============================================================================
// Spectrogram Color Maps
// =============================================================================
//
// Each color map converts a normalized magnitude value in [0.0, 1.0] to an
// ARGB color suitable for painting spectrogram pixels.
//
// Several scientifically-popular palettes are provided:
//
//   • **Viridis**    — perceptually uniform, color-blind friendly (default).
//   • **Magma**      — dark-to-bright purple/orange heat map.
//   • **Grayscale**  — simple luminance ramp.
//   • **BirdNET**    — custom palette matching the BirdNET brand blue (#0D6EFD)
//                      used as the mid-range color, from dark navy through
//                      brand blue to bright white.
//
// ### Performance
//
// Color maps are pre-computed as 256-entry lookup tables (LUTs) of raw
// `int` (ARGB8888) values stored in [Int32List].  At render time the painter
// does a single integer index into the LUT — no floating-point color math
// on the hot path.
//
// ### Adding a new color map
//
// 1. Define the gradient stops in [SpectrogramColorMap._registry].
// 2. Use `_buildLut` to interpolate the stops into a 256-entry table.
// 3. Register the name in [SpectrogramColorMap.names].
// =============================================================================

/// Registry of named color maps plus a fast per-pixel lookup.
///
/// Obtain a color map LUT with [SpectrogramColorMap.lut] and index into it
/// with `lut[(value * 255).round().clamp(0, 255)]`.
abstract final class SpectrogramColorMap {
  // ─── Public API ────────────────────────────────────────────────────────────

  /// Ordered list of available color map names for settings UI.
  static const List<String> names = [
    'viridis',
    'magma',
    'plasma',
    'cividis',
    'jet',
    'turbo',
    'grayscale',
    'birdnet',
  ];

  /// Return a 256-entry ARGB lookup table for the given color map [name].
  ///
  /// Throws [ArgumentError] if [name] is not in [names].
  static Int32List lut(String name) {
    final cached = _cache[name];
    if (cached != null) return cached;

    final stops = _registry[name];
    if (stops == null) {
      throw ArgumentError.value(name, 'name', 'Unknown color map');
    }

    final table = _buildLut(stops);
    _cache[name] = table;
    return table;
  }

  /// Convert a normalized [value] (0.0–1.0) directly to a [Color] using
  /// the color map identified by [name].
  ///
  /// Slightly slower than the LUT path — prefer [lut] in hot loops.
  static Color color(String name, double value) {
    final table = lut(name);
    final index = (value * 255).round().clamp(0, 255);
    return Color(table[index]);
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  /// Lazily-populated LUT cache (one per color map name).
  static final Map<String, Int32List> _cache = {};

  /// Gradient stop definitions.  Each list entry is a `(position, color)`
  /// pair where position ∈ [0.0, 1.0].
  static final Map<String, List<_GradientStop>> _registry = {
    'viridis': [
      _GradientStop(0.00, const Color(0xFF440154)),
      _GradientStop(0.25, const Color(0xFF3B528B)),
      _GradientStop(0.50, const Color(0xFF21918C)),
      _GradientStop(0.75, const Color(0xFF5EC962)),
      _GradientStop(1.00, const Color(0xFFFDE725)),
    ],
    'magma': [
      _GradientStop(0.00, const Color(0xFF000004)),
      _GradientStop(0.25, const Color(0xFF3B0F70)),
      _GradientStop(0.50, const Color(0xFFB63679)),
      _GradientStop(0.75, const Color(0xFFFB8761)),
      _GradientStop(1.00, const Color(0xFFFCFDBF)),
    ],
    'plasma': [
      _GradientStop(0.00, const Color(0xFF0D0887)),
      _GradientStop(0.25, const Color(0xFF7E03A8)),
      _GradientStop(0.50, const Color(0xFFCC4778)),
      _GradientStop(0.75, const Color(0xFFF89441)),
      _GradientStop(1.00, const Color(0xFFF0F921)),
    ],
    'cividis': [
      _GradientStop(0.00, const Color(0xFF00204C)),
      _GradientStop(0.25, const Color(0xFF414D6B)),
      _GradientStop(0.50, const Color(0xFF7C7B78)),
      _GradientStop(0.75, const Color(0xFFBCAA6B)),
      _GradientStop(1.00, const Color(0xFFFFEA46)),
    ],
    'jet': [
      _GradientStop(0.00, const Color(0xFF00007F)),
      _GradientStop(0.125, const Color(0xFF0000FF)),
      _GradientStop(0.375, const Color(0xFF00FFFF)),
      _GradientStop(0.625, const Color(0xFFFFFF00)),
      _GradientStop(0.875, const Color(0xFFFF0000)),
      _GradientStop(1.00, const Color(0xFF7F0000)),
    ],
    'turbo': [
      _GradientStop(0.00, const Color(0xFF30123B)),
      _GradientStop(0.10, const Color(0xFF4145AB)),
      _GradientStop(0.20, const Color(0xFF4675ED)),
      _GradientStop(0.30, const Color(0xFF39A2FC)),
      _GradientStop(0.40, const Color(0xFF1BCFD4)),
      _GradientStop(0.50, const Color(0xFF24E36F)),
      _GradientStop(0.60, const Color(0xFF61FC3C)),
      _GradientStop(0.70, const Color(0xFFB7E225)),
      _GradientStop(0.80, const Color(0xFFF9BE17)),
      _GradientStop(0.90, const Color(0xFFF66E1B)),
      _GradientStop(1.00, const Color(0xFF7A0403)),
    ],
    'grayscale': [
      // White = quiet, black = loud — matches Audacity, Raven, Sonic
      // Visualiser, matplotlib's `gray_r`, and printed sonograms in field
      // guides. Reversed from the natural black→white ramp so quiet
      // background reads as paper-white instead of a black wall (#33).
      _GradientStop(0.00, const Color(0xFFFFFFFF)),
      _GradientStop(1.00, const Color(0xFF000000)),
    ],
    // Brand-themed color map: dark navy → brand blue (#0D6EFD) → white.
    'birdnet': [
      _GradientStop(0.00, const Color(0xFF000820)),
      _GradientStop(0.30, const Color(0xFF002F6C)),
      _GradientStop(0.55, const Color(0xFF0D6EFD)),
      _GradientStop(0.80, const Color(0xFF8AB4F8)),
      _GradientStop(1.00, const Color(0xFFFFFFFF)),
    ],
  };

  /// Linearly interpolate the [stops] into a 256-entry ARGB [Int32List].
  static Int32List _buildLut(List<_GradientStop> stops) {
    final table = Int32List(256);

    for (var i = 0; i < 256; i++) {
      final t = i / 255.0;

      // Find the two surrounding stops.
      var lo = stops.first;
      var hi = stops.last;
      for (var s = 0; s < stops.length - 1; s++) {
        if (t >= stops[s].position && t <= stops[s + 1].position) {
          lo = stops[s];
          hi = stops[s + 1];
          break;
        }
      }

      // Interpolation factor within the stop interval.
      final span = hi.position - lo.position;
      final f = span > 0 ? (t - lo.position) / span : 0.0;

      // Linearly interpolate each ARGB channel.
      // Color.a/.r/.g/.b return doubles in [0.0, 1.0] — scale to [0, 255].
      final a = _lerpInt(
        (lo.color.a * 255).round(),
        (hi.color.a * 255).round(),
        f,
      );
      final r = _lerpInt(
        (lo.color.r * 255).round(),
        (hi.color.r * 255).round(),
        f,
      );
      final g = _lerpInt(
        (lo.color.g * 255).round(),
        (hi.color.g * 255).round(),
        f,
      );
      final b = _lerpInt(
        (lo.color.b * 255).round(),
        (hi.color.b * 255).round(),
        f,
      );

      // Pack into ARGB8888 integer.
      table[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }

    return table;
  }

  /// Integer lerp: `a + (b - a) * f`, clamped to [0, 255].
  static int _lerpInt(int a, int b, double f) =>
      (a + (b - a) * f).round().clamp(0, 255);
}

/// Internal gradient stop: a normalized position and its color.
class _GradientStop {
  const _GradientStop(this.position, this.color);

  /// Position in [0.0, 1.0].
  final double position;

  /// ARGB color at this position.
  final Color color;
}
