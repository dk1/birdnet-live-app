import 'package:intl/intl.dart';

String formatLocaleTime(
  DateTime dateTime,
  String localeName, {
  bool showSeconds = false,
  bool alwaysUse24HourFormat = false,
}) {
  final local = dateTime.toLocal();
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
  final dateFormatter = longMonth ? DateFormat.yMMMMd() : DateFormat.yMMMd();
  final local = dateTime.toLocal();
  return '${dateFormatter.format(local)} ${formatLocaleTime(local, localeName, alwaysUse24HourFormat: alwaysUse24HourFormat)}';
}
