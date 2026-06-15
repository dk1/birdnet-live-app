import 'package:birdnet_live/features/aru/aru_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AruScheduleConfig', () {
    test('accepts a valid repeating schedule', () {
      final config = AruScheduleConfig(
        startTime: DateTime.utc(2026, 1, 1, 6),
        cycleDuration: const Duration(minutes: 10),
        repeatInterval: const Duration(hours: 1),
        maxCycles: 3,
        lowBatteryStopPercent: 15,
      );

      expect(config.validate(), isEmpty);
    });

    test('rejects invalid duration, interval, end, cycles, and battery', () {
      final start = DateTime.utc(2026, 1, 1, 6);
      final config = AruScheduleConfig(
        startTime: start,
        cycleDuration: const Duration(seconds: 15),
        repeatInterval: const Duration(seconds: 10),
        endTime: start,
        maxCycles: 0,
        lowBatteryStopPercent: 101,
      );

      expect(
        config.validate(),
        containsAll(<String>[
          'cycleDuration must be at least 30 seconds',
          'repeatInterval must be greater than or equal to cycleDuration',
          'endTime must be after startTime',
          'maxCycles must be greater than zero',
          'lowBatteryStopPercent must be between 0 and 100',
        ]),
      );
    });

    test('accepts diel recording windows', () {
      final config = AruScheduleConfig(
        startTime: DateTime.utc(2026, 1, 1, 6),
        cycleDuration: const Duration(minutes: 10),
        repeatInterval: const Duration(hours: 1),
        dielPattern: AruDielPattern.aroundSunrise,
      );

      expect(config.validate(), isEmpty);
    });
  });

  group('AruScheduleCalculator', () {
    late DateTime start;
    late AruScheduleCalculator calculator;

    setUp(() {
      start = DateTime.utc(2026, 1, 1, 6);
      calculator = AruScheduleCalculator(
        AruScheduleConfig(
          startTime: start,
          cycleDuration: const Duration(minutes: 10),
          repeatInterval: const Duration(hours: 1),
          maxCycles: 3,
        ),
      );
    });

    test('reports not started before the first window', () {
      final snapshot = calculator.snapshotAt(
        start.subtract(const Duration(minutes: 5)),
      );

      expect(snapshot.status, AruScheduleStatus.notStarted);
      expect(snapshot.skippedCycles, 0);
      expect(snapshot.nextWindow?.index, 0);
      expect(snapshot.nextWindow?.start, start);
    });

    test('reports recording inside a window', () {
      final snapshot = calculator.snapshotAt(
        start.add(const Duration(minutes: 5)),
      );

      expect(snapshot.status, AruScheduleStatus.recording);
      expect(snapshot.currentWindow?.index, 0);
      expect(
        snapshot.currentWindow?.end,
        start.add(const Duration(minutes: 10)),
      );
      expect(snapshot.nextWindow?.index, 1);
    });

    test('reports waiting between windows', () {
      final snapshot = calculator.snapshotAt(
        start.add(const Duration(minutes: 15)),
      );

      expect(snapshot.status, AruScheduleStatus.waiting);
      expect(snapshot.skippedCycles, 1);
      expect(snapshot.nextWindow?.index, 1);
      expect(snapshot.nextWindow?.start, start.add(const Duration(hours: 1)));
    });

    test('reports completed after max cycles', () {
      final snapshot = calculator.snapshotAt(
        start.add(const Duration(hours: 3)),
      );

      expect(snapshot.status, AruScheduleStatus.completed);
      expect(snapshot.skippedCycles, 3);
      expect(snapshot.nextWindow, isNull);
    });

    test('returns future windows including an active current window', () {
      final windows = calculator.nextWindows(
        start.add(const Duration(minutes: 5)),
        count: 3,
      );

      expect(windows.map((w) => w.index), <int>[0, 1, 2]);
    });

    test('skips elapsed windows in next window previews', () {
      final windows = calculator.nextWindows(
        start.add(const Duration(minutes: 15)),
        count: 3,
      );

      expect(windows.map((w) => w.index), <int>[1, 2]);
    });

    test('aligns regular cycles to clock interval boundaries', () {
      final deployedAt = DateTime.utc(2026, 1, 1, 6, 17);
      final calc = AruScheduleCalculator(
        AruScheduleConfig(
          startTime: deployedAt,
          cycleDuration: const Duration(minutes: 10),
          repeatInterval: const Duration(hours: 1),
          maxCycles: 2,
        ),
      );

      final windows = calc.nextWindows(deployedAt, count: 2);

      expect(windows.map((w) => w.start), <DateTime>[
        DateTime.utc(2026, 1, 1, 7),
        DateTime.utc(2026, 1, 1, 8),
      ]);
    });

    test('runs optional immediate test cycle before regular cycles', () {
      final deployedAt = DateTime.utc(2026, 1, 1, 6, 17);
      final calc = AruScheduleCalculator(
        AruScheduleConfig(
          startTime: deployedAt,
          cycleDuration: const Duration(minutes: 10),
          repeatInterval: const Duration(hours: 1),
          maxCycles: 2,
          testCycleEnabled: true,
        ),
      );

      final windows = calc.nextWindows(deployedAt, count: 3);

      expect(windows.map((w) => w.index), <int>[0, 1, 2]);
      expect(windows[0].start, deployedAt);
      expect(windows[0].end, deployedAt.add(const Duration(minutes: 1)));
      expect(windows[1].start, DateTime.utc(2026, 1, 1, 7));
      expect(windows[2].start, DateTime.utc(2026, 1, 1, 8));
    });

    test('postpones aligned start to prevent overlap with 1min test cycle', () {
      final deployedAt = DateTime.utc(2026, 1, 1, 6);
      final calc = AruScheduleCalculator(
        AruScheduleConfig(
          startTime: deployedAt,
          cycleDuration: const Duration(minutes: 10),
          repeatInterval: const Duration(hours: 1),
          maxCycles: 2,
          testCycleEnabled: true,
        ),
      );

      final windows = calc.nextWindows(deployedAt, count: 3);

      expect(windows.map((w) => w.index), <int>[0, 1, 2]);
      expect(windows[0].start, deployedAt);
      expect(windows[0].end, deployedAt.add(const Duration(minutes: 1)));
      expect(windows[1].start, DateTime.utc(2026, 1, 1, 7));
      expect(windows[2].start, DateTime.utc(2026, 1, 1, 8));
    });

    test('clamps a cycle at deployment end', () {
      final end = start.add(const Duration(minutes: 65));
      final calc = AruScheduleCalculator(
        AruScheduleConfig(
          startTime: start,
          cycleDuration: const Duration(minutes: 30),
          repeatInterval: const Duration(hours: 1),
          endTime: end,
        ),
      );

      final windows = calc.nextWindows(start, count: 3);

      expect(windows.length, 2);
      expect(windows.last.index, 1);
      expect(windows.last.end, end);
      expect(windows.last.isClamped, isTrue);
    });

    test('uses 6am and 6pm fallback for daylight windows without location', () {
      final midnight = DateTime.utc(2026, 1, 1);
      final calc = AruScheduleCalculator(
        AruScheduleConfig(
          startTime: midnight,
          cycleDuration: const Duration(minutes: 10),
          repeatInterval: const Duration(hours: 1),
          maxCycles: 3,
          dielPattern: AruDielPattern.dayOnly,
        ),
      );

      final windows = calc.nextWindows(midnight, count: 3);

      expect(windows.map((w) => w.start.hour), <int>[6, 7, 8]);
    });

    test('uses fallback sunrise window when location is unavailable', () {
      final midnight = DateTime.utc(2026, 1, 1);
      final calc = AruScheduleCalculator(
        AruScheduleConfig(
          startTime: midnight,
          cycleDuration: const Duration(minutes: 10),
          repeatInterval: const Duration(hours: 1),
          maxCycles: 3,
          dielPattern: AruDielPattern.aroundSunrise,
        ),
      );

      final windows = calc.nextWindows(midnight, count: 2);

      expect(windows.map((w) => w.start.hour), <int>[5, 6]);
    });
  });
}
