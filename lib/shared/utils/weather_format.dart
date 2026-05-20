// =============================================================================
// weather_format.dart
//
// Small formatting helpers for `WeatherSnapshot` values.
//
// Centralizes:
//   * WMO weather code → short human label key (resolved via AppLocalizations
//     by the caller, since this util is intentionally context-free).
//   * WMO weather code → Material/MDI icon.
//   * Compass-bearing → 8-point cardinal abbreviation.
//   * Compact stat strings ("20.1 °C · 3.2 m/s S") used in space-tight UI.
//   * Descriptive one-line summary strings ("20.1 °C · Light rain · Wind 3 m/s S")
//     used where verbal condition labels are appropriate.
//
// Why a dedicated file: the same logic is used in three layers
// (UI, HTML, CSV/JSON exports) and we want a single source of truth so
// translations and units stay consistent.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../models/weather_snapshot.dart';

/// Symbolic keys for WMO weather code groups. The caller is expected to
/// resolve these via `AppLocalizations` for user-facing text.
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunder,
  unknown,
}

/// Maps a WMO weather code (returned by Open-Meteo) to a coarse condition
/// bucket. Codes follow https://open-meteo.com/en/docs (WW table).
WeatherCondition weatherConditionFromCode(int? code) {
  if (code == null) return WeatherCondition.unknown;
  if (code == 0) return WeatherCondition.clear;
  if (code == 1 || code == 2) return WeatherCondition.partlyCloudy;
  if (code == 3) return WeatherCondition.cloudy;
  if (code == 45 || code == 48) return WeatherCondition.fog;
  if (code >= 51 && code <= 57) return WeatherCondition.drizzle;
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
    return WeatherCondition.rain;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return WeatherCondition.snow;
  }
  if (code >= 95 && code <= 99) return WeatherCondition.thunder;
  return WeatherCondition.unknown;
}

/// Material icon for a weather condition.
IconData weatherConditionIcon(WeatherCondition cond) {
  switch (cond) {
    case WeatherCondition.clear:
      return AppIcons.wbSunny;
    case WeatherCondition.partlyCloudy:
      return AppIcons.wbCloudy;
    case WeatherCondition.cloudy:
      return AppIcons.cloud;
    case WeatherCondition.fog:
      return AppIcons.foggy;
    case WeatherCondition.drizzle:
      return AppIcons.grain;
    case WeatherCondition.rain:
      return AppIcons.waterDrop;
    case WeatherCondition.snow:
      return AppIcons.acUnit;
    case WeatherCondition.thunder:
      return AppIcons.thunderstorm;
    case WeatherCondition.unknown:
      return AppIcons.helpOutline;
  }
}

/// 8-point compass abbreviation (English; left untranslated as a technical
/// term, like map units elsewhere in the app).
String compassFromBearing(double? deg) {
  if (deg == null) return '';
  final normalized = ((deg % 360) + 360) % 360;
  const sectors = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final idx = ((normalized + 22.5) / 45).floor() % 8;
  return sectors[idx];
}

/// Short label like "20.1 °C" / "—" when missing.
String formatTemperature(double? celsius) {
  if (celsius == null) return '—';
  return '${celsius.toStringAsFixed(1)} °C';
}

/// "3.2 m/s SW" / "3.2 m/s" / "—".
String formatWind(double? speedMs, double? bearingDeg) {
  if (speedMs == null) return '—';
  final compass = compassFromBearing(bearingDeg);
  final base = '${speedMs.toStringAsFixed(1)} m/s';
  return compass.isEmpty ? base : '$base $compass';
}

/// "0.2 mm" / "—".
String formatPrecipitation(double? mm) {
  if (mm == null) return '—';
  return '${mm.toStringAsFixed(1)} mm';
}

/// "60 %" / "—".
String formatCloudCover(int? percent) {
  if (percent == null) return '—';
  return '$percent %';
}

/// Compact setup/review label with no verbal condition text.
///
/// The condition is represented by [weatherConditionIcon] in the UI so this
/// string deliberately keeps only numeric field data: temperature + wind.
String formatWeatherCompactStats(WeatherSnapshot w) {
  final parts = <String>[];
  if (w.temperatureC != null) parts.add(formatTemperature(w.temperatureC));
  if (w.windSpeedMs != null) {
    parts.add(formatWind(w.windSpeedMs, w.windDirectionDeg));
  }
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// Resolves a `WeatherCondition` to a human label using the provided lookup
/// callback (so this file does not depend on AppLocalizations directly).
typedef WeatherLabelLookup = String Function(WeatherCondition);

/// One-line "20.1 °C · Light rain · Wind 3 m/s SW" used as a quick summary.
/// The condition label is resolved via [labelFor].
String formatWeatherOneLine(WeatherSnapshot w, WeatherLabelLookup labelFor) {
  final parts = <String>[];
  if (w.temperatureC != null) parts.add(formatTemperature(w.temperatureC));
  parts.add(labelFor(weatherConditionFromCode(w.weatherCode)));
  if (w.windSpeedMs != null) {
    parts.add(formatWind(w.windSpeedMs, w.windDirectionDeg));
  }
  return parts.join(' · ');
}
