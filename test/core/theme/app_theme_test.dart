import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/core/theme/app_semantic_colors.dart';
import 'package:birdnet_live/core/theme/app_theme.dart';
import 'package:birdnet_live/core/theme/score_colors.dart';

void main() {
  group('AppTheme variants', () {
    test(
      'standard light theme keeps brand and functional color extensions',
      () {
        final theme = AppTheme.light();
        final semanticColors = theme.extension<AppSemanticColors>()!;

        expect(AppTheme.isHighContrastTheme(theme), isFalse);
        expect(theme.colorScheme.primary, AppTheme.brandPrimary);
        expect(theme.colorScheme.onSurface, Colors.black);
        expect(theme.extension<ScoreColors>(), same(ScoreColors.light));
        expect(semanticColors.success, AppSemanticColors.light.success);
        expect(semanticColors.sessionLive, AppSemanticColors.light.sessionLive);
        expect(
          semanticColors.sessionFileAnalysis,
          AppSemanticColors.light.sessionFileAnalysis,
        );
      },
    );

    test('standard dark theme keeps brand and functional color extensions', () {
      final theme = AppTheme.dark();
      final semanticColors = theme.extension<AppSemanticColors>()!;

      expect(AppTheme.isHighContrastTheme(theme), isFalse);
      expect(theme.colorScheme.primary, AppTheme.brandPrimaryLight);
      expect(theme.extension<ScoreColors>(), same(ScoreColors.dark));
      expect(semanticColors.success, AppSemanticColors.light.success);
      expect(
        semanticColors.sessionSurvey,
        AppSemanticColors.light.sessionSurvey,
      );
    });

    test('dynamic color theme is not treated as high contrast', () {
      final theme = AppTheme.fromColorScheme(
        const ColorScheme.light(
          primary: Colors.purple,
          primaryContainer: Colors.deepPurple,
          surface: Color(0xFFFFFBFE),
        ),
      );
      final semanticColors = theme.extension<AppSemanticColors>()!;

      expect(AppTheme.isHighContrastTheme(theme), isFalse);
      expect(theme.colorScheme.primary, Colors.purple);
      expect(theme.extension<ScoreColors>(), same(ScoreColors.light));
      expect(semanticColors.success, isNot(theme.colorScheme.primary));
    });

    test('high contrast light preserves score, success, and mode colors', () {
      final theme = AppTheme.highContrastLight();
      final semanticColors = theme.extension<AppSemanticColors>()!;

      expect(AppTheme.isHighContrastTheme(theme), isTrue);
      expect(theme.colorScheme.primary, Colors.black);
      expect(theme.colorScheme.surface, Colors.white);
      expect(theme.extension<ScoreColors>(), same(ScoreColors.light));
      expect(semanticColors.success, isNot(theme.colorScheme.primary));
      expect(semanticColors.success, isNot(theme.colorScheme.onSurface));
      expect(semanticColors.sessionLive, AppSemanticColors.light.sessionLive);
      expect(
        semanticColors.sessionPointCount,
        AppSemanticColors.light.sessionPointCount,
      );
      expect(semanticColors.sessionAru, AppSemanticColors.light.sessionAru);
    });

    test('high contrast dark preserves score, success, and mode colors', () {
      final theme = AppTheme.highContrastDark();
      final semanticColors = theme.extension<AppSemanticColors>()!;

      expect(AppTheme.isHighContrastTheme(theme), isTrue);
      expect(theme.colorScheme.primary, Colors.white);
      expect(theme.colorScheme.surface, Colors.black);
      expect(theme.extension<ScoreColors>(), same(ScoreColors.dark));
      expect(semanticColors.success, isNot(theme.colorScheme.primary));
      expect(semanticColors.success, isNot(theme.colorScheme.onSurface));
      expect(
        semanticColors.sessionSurvey,
        AppSemanticColors.light.sessionSurvey,
      );
      expect(
        semanticColors.sessionBatchAnalysis,
        AppSemanticColors.light.sessionBatchAnalysis,
      );
    });
  });
}
