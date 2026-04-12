// =============================================================================
// Survey Map Widget — Live map with GPS track and detection pins
// =============================================================================
//
// Displays an OpenTopoMap tile layer with the GPS track as a polyline and
// detection locations as colored markers.  Used both during an active survey
// and in session review.
//
// Privacy: Requires map tile consent (checked via SharedPreferences).
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/gps_point.dart';
import '../../../shared/providers/app_providers.dart';
import '../../live/live_session.dart';

/// Live map showing GPS track and detection markers.
class SurveyMapWidget extends ConsumerStatefulWidget {
  const SurveyMapWidget({
    super.key,
    required this.gpsTrack,
    required this.detections,
    this.autoFollow = true,
  });

  /// GPS track points.
  final List<GpsPoint> gpsTrack;

  /// Detections to show as markers.
  final List<DetectionRecord> detections;

  /// Whether the map auto-centers on the latest GPS point.
  final bool autoFollow;

  @override
  ConsumerState<SurveyMapWidget> createState() => _SurveyMapWidgetState();
}

class _SurveyMapWidgetState extends ConsumerState<SurveyMapWidget> {
  final MapController _mapController = MapController();
  bool? _hasConsent;
  int _lastTrackLength = 0;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  @override
  void didUpdateWidget(covariant SurveyMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-follow: move camera when new GPS points arrive.
    if (widget.autoFollow &&
        widget.gpsTrack.length != _lastTrackLength &&
        widget.gpsTrack.isNotEmpty) {
      _lastTrackLength = widget.gpsTrack.length;
      final last = widget.gpsTrack.last;
      _mapController.move(
        LatLng(last.latitude, last.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  void _checkConsent() {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _hasConsent = prefs.getBool(PrefKeys.mapTileConsent) ?? false;
    });
  }

  Future<void> _requestConsent() async {
    final l10n = AppLocalizations.of(context)!;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mapTileConsentTitle),
        content: Text(l10n.mapTileConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.mapTileConsentCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.mapTileConsentAllow),
          ),
        ],
      ),
    );
    if (agreed == true) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(PrefKeys.mapTileConsent, true);
      setState(() => _hasConsent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasConsent != true) {
      return _buildConsentPlaceholder(context);
    }
    return _buildMap(context);
  }

  Widget _buildMap(BuildContext context) {
    final theme = Theme.of(context);

    // Build polyline from GPS track.
    final trackPoints =
        widget.gpsTrack.map((p) => LatLng(p.latitude, p.longitude)).toList();

    // Build detection markers.
    final markers = <Marker>[];
    for (final det in widget.detections) {
      if (det.latitude == null || det.longitude == null) continue;
      markers.add(
        Marker(
          point: LatLng(det.latitude!, det.longitude!),
          width: 24,
          height: 24,
          child: _DetectionPin(confidence: det.confidence, theme: theme),
        ),
      );
    }

    // Add start/end markers.
    if (trackPoints.isNotEmpty) {
      markers.insert(
        0,
        Marker(
          point: trackPoints.first,
          width: 32,
          height: 32,
          child:
              Icon(Icons.flag_rounded, color: Colors.green.shade700, size: 32),
        ),
      );
      if (trackPoints.length > 1) {
        markers.add(
          Marker(
            point: trackPoints.last,
            width: 32,
            height: 32,
            child: Icon(Icons.person_pin_circle_rounded,
                color: theme.colorScheme.primary, size: 32),
          ),
        );
      }
    }

    // Determine center and zoom.
    LatLng center;
    double zoom;
    if (trackPoints.isNotEmpty) {
      center = trackPoints.last;
      zoom = 18;
    } else {
      center = const LatLng(52.52, 13.405); // Berlin default
      zoom = 10;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'birdnet_live',
          tileProvider: _CachingTileProvider(),
        ),
        if (trackPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: trackPoints,
                strokeWidth: 3,
                color: theme.colorScheme.primary.withAlpha(180),
              ),
            ],
          ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap (ODbL)', onTap: () {}),
            TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildConsentPlaceholder(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 48, color: theme.colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _requestConsent,
              icon: const Icon(Icons.map),
              label: Text(l10n.mapLoadButton),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mapLoadHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detection pin marker
// ─────────────────────────────────────────────────────────────────────────────

class _DetectionPin extends StatelessWidget {
  const _DetectionPin({required this.confidence, required this.theme});
  final double confidence;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.8
        ? Colors.green
        : confidence >= 0.5
            ? Colors.amber.shade700
            : Colors.red;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color.withAlpha(180),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caching tile provider
// ─────────────────────────────────────────────────────────────────────────────

class _CachingTileProvider extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
    );
  }
}
