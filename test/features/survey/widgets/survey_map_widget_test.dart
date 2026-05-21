import 'package:birdnet_live/features/survey/widgets/survey_map_widget.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('Survey map accessibility widgets', () {
    testWidgets('marker semantics expose species, confidence, audio, and confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SurveyMapMarkerSemantics(
            label: 'Great Tit',
            confidence: 0.87,
            hasAudio: true,
            isConfirmed: true,
            onTap: () {},
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      try {
        final markerFinder = find.bySemanticsLabel('Great Tit');

        expect(
          tester.getSemantics(markerFinder),
          matchesSemantics(
            label: 'Great Tit',
            value: 'Confidence 87 percent, Audio clip available, Confirmed',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasSelectedState: true,
            hasTapAction: true,
          ),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('cluster bubble exposes localized detection count semantics', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const SurveyMapClusterBubble(count: 2)));

      final semantics = tester.ensureSemantics();
      try {
        expect(find.bySemanticsLabel('2 detections'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  });
}
