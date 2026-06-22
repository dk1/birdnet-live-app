import 'package:intl/intl.dart';

String formatLocaleTime(
  DateTime dateTime,
  String localeName, {
  bool showSeconds = false,
  bool alwaysUse24HourFormat = false,
}) {
  final local = dateTime.toLocal();
  try {
    final formatter =
        alwaysUse24HourFormat
            ? (showSeconds
                ? DateFormat.Hms(localeName)
                : DateFormat.Hm(localeName))
            : (showSeconds
                ? DateFormat.jms(localeName)
                : DateFormat.jm(localeName));
    return formatter.format(local);
  } catch (_) {
    return _fallbackTime(
      local,
      showSeconds: showSeconds,
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    );
  }
}

String _fallbackTime(
  DateTime local, {
  required bool showSeconds,
  required bool alwaysUse24HourFormat,
}) {
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  if (alwaysUse24HourFormat) {
    final hour = local.hour.toString().padLeft(2, '0');
    return showSeconds ? '$hour:$minute:$second' : '$hour:$minute';
  }

  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final dayPeriod = local.hour < 12 ? 'AM' : 'PM';
  return showSeconds
      ? '$hour:$minute:$second $dayPeriod'
      : '$hour:$minute $dayPeriod';
}

String formatLocaleDateTime(
  DateTime dateTime,
  String localeName, {
  bool longMonth = false,
  bool alwaysUse24HourFormat = false,
}) {
  final local = dateTime.toLocal();
  String dateText;
  try {
    final dateFormatter =
        longMonth
            ? DateFormat.yMMMMd(localeName)
            : DateFormat.yMMMd(localeName);
    dateText = dateFormatter.format(local);
  } catch (_) {
    final dateFormatter = longMonth ? DateFormat.yMMMMd() : DateFormat.yMMMd();
    dateText = dateFormatter.format(local);
  }
  return '$dateText ${formatLocaleTime(local, localeName, alwaysUse24HourFormat: alwaysUse24HourFormat)}';
}
