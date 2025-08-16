import 'package:escive/main.dart';
import 'package:escive/utils/geolocator.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/show_snackbar.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart' as localization;
import 'package:logarte/logarte.dart';

void checkWeather() async {
  // Check if we need to check the weather data
  if(globals.settings['enableWeatherCheck'] != true) return logarte.log("Weather: not checking weather data because the feature is disabled in settings");
  if(globals.positionEmitter.currentlyEmittingPositionRealTime != true) return logarte.log("Weather: not checking weather data because position emitter is not active");
  if(globals.lastWeatherCheckDate.isNotEmpty && DateTime.now().difference(DateTime.parse(globals.lastWeatherCheckDate)).inMinutes < 5) return logarte.log("Weather: not checking weather data because last check was less than 5 minutes ago");
  logarte.log("Weather: checking weather data...");

  // If the last fetch was more than 20 minutes ago, we will fetch new data
  if(globals.lastWeatherData.isEmpty || globals.lastWeatherFetchDate.isEmpty || (globals.lastWeatherFetchDate.isNotEmpty && DateTime.now().difference(DateTime.parse(globals.lastWeatherFetchDate)).inMinutes > 20)) {
    logarte.log("Weather: last fetch was more than 20 minutes ago, fetching new data...");

    // Get user position
    Position? currentPosition;
    try {
      currentPosition = await getCurrentPosition(LocationAccuracy.reduced);
    } catch (e) {
      return logarte.log("Weather: could not get current position for weather check: $e");
    }

    // Fetch weather data
    try {
      globals.lastWeatherCheckDate = DateTime.now().toIso8601String(); // doesn't update the last fetch date for now
      String stringifiedUrl = 'https://webservice.meteofrance.com/v3/rain?lat=${currentPosition.latitude}&lon=${currentPosition.longitude}&token=__Wj7dVSTjV9YGu1guveLyDq0g7S7TfTjaHBTPTpO0kj8__';
      final response = await http.get(Uri.parse(stringifiedUrl));

      logarte.network(
        request: NetworkRequestLogarteEntry(
          method: 'POST',
          url: stringifiedUrl,
          headers: {}
        ),
        response: NetworkResponseLogarteEntry(
          statusCode: response.statusCode,
          headers: response.headers,
          body: response.body,
        ),
      );

      if (response.statusCode == 200) {
        final weatherData = response.body;
        logarte.log("Weather: data fetched successfully, parsing...");

        // Parse the weather data
        final parsedData = json.decode(weatherData);
        if (parsedData is! Map) return logarte.log("Weather: parsed data is not a valid JSON object");

        globals.lastWeatherData = parsedData;
        globals.lastWeatherFetchDate = DateTime.now().toIso8601String();
      } else {
        return logarte.log("Weather: failed to fetch data: ${response.statusCode}");
      }
    } catch (e) {
      globals.lastWeatherCheckDate = DateTime.now().toIso8601String(); // doesn't update the last fetch date too
      return logarte.log("Weather: error fetching weather data: $e");
    }
  } else {
    logarte.log("Weather: last fetch was less than 20 minutes ago, using cached data");
    globals.lastWeatherCheckDate = DateTime.now().toIso8601String();
  }

  // Check if the fetched datas are valid
  if(globals.lastWeatherData.isEmpty) return logarte.log("Weather: no weather data available to process");
  if(!globals.lastWeatherData.containsKey('properties')) return logarte.log("Weather: fetched data does not contain 'properties' key");
  if(!globals.lastWeatherData['properties'].containsKey('forecast')) return logarte.log("Weather: fetched data does not contain 'properties.forecast' key");
  // if(globals.lastWeatherData['properties'].containsKey('rain_product_available') && globals.lastWeatherData['properties']['rain_product_available'] != 1) return logarte.log("Weather: rain data are not available for the current position"); // outdated??

  bool notConfident = globals.lastWeatherData['properties'].containsKey('confidence') && globals.lastWeatherData['properties']['confidence'] > 1.5; // 0 = very confident, 3 = not confident at all
  int minutesUntilRain = -1; // -1 = no rain expected, 0 = currently raining, >0 = minutes until it start to rain

  final List<dynamic> forecast = globals.lastWeatherData['properties']['forecast'];
  final DateTime now = DateTime.now().toUtc();

  for (final entry in forecast) {
    if (entry is Map && entry.containsKey('time') && entry.containsKey('rain_intensity')) {
      final DateTime forecastTime = DateTime.parse(entry['time']);
      final int rainIntensity = entry['rain_intensity'];

      if (rainIntensity >= 2) {
        final int diffMinutes = forecastTime.difference(now).inMinutes;

        if (diffMinutes <= 0) {
          minutesUntilRain = 0;
          return; // No need to check further, it is already raining
        } else {
          minutesUntilRain = diffMinutes;
          break;
        }
      }
    }
  }

  // Tell user using a snackbar if it is going to rain
  if (minutesUntilRain > 0) {
    logarte.log("Weather: it is going to rain in $minutesUntilRain minutes (confidence: ${globals.lastWeatherData['properties']['confidence']})");

    final context = globals.navigatorKey.currentContext;
    if(context != null && context.mounted){
      Haptic().warning();
      showSnackBar(
        context,
        "weather.text".tr(namedArgs: {
          "confident": notConfident ? "weather.notConfident".tr() : "weather.confident".tr(),
          "time": minutesUntilRain.toString()
        }),
      );
    } else {
      logarte.log("Weather: cannot access context to show snackbar, skipping...");
    }
  } else if (minutesUntilRain == 0) {
    logarte.log("Weather: it is currently raining (confidence: ${globals.lastWeatherData['properties']['confidence']})");
  } else {
    logarte.log("Weather: no rain expected in the next hours");
  }
}