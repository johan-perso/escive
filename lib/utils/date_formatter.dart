import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

String getRelativeTime(String locale, DateTime dateTime, String additional) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  String additionalType = "dateFormatter.additional.$additional.type".tr();
  String prefix = '';
  String suffix = '';
  if(additionalType == 'prefix'){
    prefix = "dateFormatter.additional.$additional.label".tr();
    if(prefix.isNotEmpty && !prefix.endsWith(' ')) prefix += ' '; // Add space to end if not already there
  } else if(additionalType == 'suffix'){
    suffix = "dateFormatter.additional.$additional.label".tr();
    if(suffix.isNotEmpty && suffix.startsWith(' ')) suffix = suffix.substring(1); // Remove space from start if there
  }

  // If date is in the future
  if (difference.isNegative) {
    return DateFormat.yMMMd(locale).format(dateTime);
  }

  // Less than a minute
  if (difference.inMinutes < 1) {
    return 'dateFormatter.justnow'.tr();
  }

  // Less than an hour
  if (difference.inHours < 1) {
    final minutes = difference.inMinutes;
    return '$prefix$minutes min $suffix';
  }

  // Less than a day
  if (difference.inDays < 1) {
    final hours = difference.inHours;
    return '$prefix$hours ${'dateFormatter.hour'.plural(1000000)} $suffix';
  }

  // Yesterday or two days ago
  if (difference.inDays == 1) {
    return '${prefix == 'depuis' || prefix == 'since' ? prefix : ''}${'dateFormatter.yesterday'.tr()}';
  }
  if (difference.inDays == 2 && locale.startsWith('fr')) { // only in french
    return '${prefix == 'depuis' || prefix == 'since' ? prefix : ''}${'dateFormatter.beforeYesterday'.tr()}';
  }

  // Less than a week
  if (difference.inDays < 7) {
    return '$prefix${difference.inDays} ${'dateFormatter.day'.plural(difference.inDays)} $suffix';
  }

  // Less than a month
  if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return '$prefix$weeks ${'dateFormatter.week'.plural(weeks)} $suffix';
  }

  // Less than a year
  if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    if (months == 1) {
      return '${prefix == 'depuis' ? prefix : ''}${'dateFormatter.lastMonth'.tr()} ${suffix == 'ago' ? suffix : ''}';
    }
    return '$prefix$months ${'dateFormatter.month'.plural(months)} $suffix';
  }

  // More than a year
  return DateFormat.yMMMd(locale).format(dateTime);
}