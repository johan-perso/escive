import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

int dayOfYear(DateTime date) {
  DateTime startOfYear = DateTime(date.year, 1, 1);
  return date.difference(startOfYear).inDays + 1;
}

String humanReadableTime(int seconds) {  
  // Returns `12min`, `10h12`, `1j 12h, 30min`

  int days = (seconds / 86400).floor();
  int hours = ((seconds % 86400) / 3600).floor();
  int minutes = (((seconds % 86400) % 3600) / 60).floor();

  String daysTrad = 'dateFormatter.day.one'.tr().toLowerCase().substring(0, 1);
  String hoursTrad = 'dateFormatter.hour.one'.tr().toLowerCase().substring(0, 1);

  bool longerFormat = days > 0;
  String readableTime = '';


  if(days > 0) readableTime += "$days$daysTrad ";
  if(hours > 0) readableTime += "$hours$hoursTrad${longerFormat ? ' ' : ''}";
  if(minutes > 0) readableTime += "${minutes < 10 ? '0' : ''}$minutes${hours < 1 && !longerFormat ? ' min' : longerFormat ? 'm' : ''} ";
  if(readableTime.isEmpty) readableTime = '0 min';

  return readableTime;
}

String humanReadableDistance(dynamic distance, { String fromUnit = 'm', int decimalPlaces = 1 }) {
  if(distance.runtimeType != double){
    try { // try to parse another way, in case if it's a string or a double
      distance = double.parse(distance.toString());
    } catch (e) {
      distance = 0;
    }
  }
  distance ??= 0; // set distance to 0 if still null

  if(fromUnit == 'km') distance = distance * 1000; // unit of the distance, will be converted to meters

  String? readableDistance;

  if(distance < 1000){
    readableDistance = "${distance.toStringAsFixed(0)} m";
  } else {
    readableDistance = "${(distance/1000).toStringAsFixed(decimalPlaces)} km";
  }

  if(readableDistance.contains('.0 ')) readableDistance = readableDistance.replaceAll('.0 ', ' ');
  return readableDistance.replaceAll('.', ',');
}

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