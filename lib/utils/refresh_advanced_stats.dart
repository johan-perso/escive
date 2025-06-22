import 'package:escive/main.dart';
import 'package:escive/utils/date_formatter.dart';
import 'package:escive/utils/globals.dart' as globals;

bool isRefreshingAdvancedStats = false;
DateTime _lastAdvancedStatsRefresh = DateTime.fromMillisecondsSinceEpoch(0);

void refreshAdvancedStats(){
  if(globals.settings['useAdvancedStats'] != true) return; // check if advanced stats are enabled
  if(globals.currentDevice.isEmpty) return; // check if we're connected
  if(!globals.currentDevice.containsKey('currentActivity') || globals.currentDevice['currentActivity']['state'] == 'none') return; // check if we're connected
  if(!globals.currentDevice.containsKey('stats')) return; // check if current device has stats map

  DateTime now = DateTime.now();
  Map globalsStats = globals.currentDevice['stats'];

  if(isRefreshingAdvancedStats && now.difference(_lastAdvancedStatsRefresh).inMinutes < 5) return; // avoid refreshing if already refreshing, we check time in case there's a bug and we never redefine the refresh state
  if(now.difference(_lastAdvancedStatsRefresh).inSeconds < 55) return; // check if we're not refreshing too often (55 seconds)

  isRefreshingAdvancedStats = true;
  _lastAdvancedStatsRefresh = now;

  // If we don't have the last midnight time, or it was not today, set it to now
  if(globalsStats['datas']['lastMidnightTime'] == null || DateTime.parse(globalsStats['datas']['lastMidnightTime']).day != now.day){
    globalsStats['datas']['lastMidnightTime'] = now.toIso8601String();
    globalsStats['datas']['totalDistanceKmAtMidnight'] = globalsStats['totalDistanceKm'];
  }

  // Define the distance traveled since last midnight
  globalsStats['todayDistanceKm'] = globalsStats['totalDistanceKm'] - globalsStats['datas']['totalDistanceKmAtMidnight'];
  globalsStats['datas']['allDaysDistanceKm'][dayOfYear(now).toString()] = globalsStats['todayDistanceKm'];

  // Define the distance traveled in the last 7 days
  double weekDistanceKm = 0;
  for(int i = 0; i <= 6; i++){
    String currentDayInYear = dayOfYear(now.subtract(Duration(days: i))).toString();
    if(globalsStats['datas']['allDaysDistanceKm'].containsKey(currentDayInYear)){ // if we got a data for that day, add it
      try {
        weekDistanceKm += double.parse(globalsStats['datas']['allDaysDistanceKm'][currentDayInYear].toString());
      } catch(e){
        weekDistanceKm += double.tryParse(globalsStats['datas']['allDaysDistanceKm'][currentDayInYear].toString()) ?? 0;
      }
    }
  }
  globalsStats['weekDistanceKm'] = weekDistanceKm;

  // Define the average speed
  final stopwatch = Stopwatch()..start();
  List lastSpeedsKmh = globalsStats['datas']['lastSpeedsKmh'];
  if(lastSpeedsKmh.length > 1000) lastSpeedsKmh.removeAt(0);
  double averageSpeedKmh = 0;
  for(int i = 0; i < lastSpeedsKmh.length; i++){
    averageSpeedKmh += lastSpeedsKmh[i];
  }
  averageSpeedKmh = averageSpeedKmh / lastSpeedsKmh.length;
  if(averageSpeedKmh.isNaN || averageSpeedKmh.isNegative || averageSpeedKmh.isInfinite) averageSpeedKmh = 0;

  globalsStats['averageSpeedKmh'] = averageSpeedKmh;
  stopwatch.stop();
  logarte.log('Average speed took ${stopwatch.elapsedMilliseconds}ms to calculate');

  globals.currentDevice['stats'] = globalsStats;
  globals.saveInBox();
  isRefreshingAdvancedStats = false;
}

void addNewPositionOnMap({ double? longitude, double? latitude, double? speedKmh }){
  if(longitude == null || latitude == null) return; // check we received a position
  if(globals.settings['useAdvancedStats'] != true) return; // check if advanced stats are enabled
  if(globals.settings['logsPositionHistory'] != true) return; // check if position history is enabled
  if(globals.currentDevice.isEmpty) return; // check if we're connected
  if(!globals.currentDevice.containsKey('currentActivity') || globals.currentDevice['currentActivity']['state'] == 'none') return; // check if we're connected
  if(!globals.currentDevice.containsKey('stats')) return; // stats map should always be defined

  if(!globals.currentDevice['stats'].containsKey('positionHistory')) globals.currentDevice['stats']['positionHistory'] = [];

  // Check last element
  if(globals.currentDevice['stats']['positionHistory'].length > 0){
    Map lastPosition = globals.currentDevice['stats']['positionHistory'].last;

    if(lastPosition['longitude'] == longitude && lastPosition['latitude'] == latitude) return; // last element should not be at the same coordinates
    if(DateTime.now().difference(DateTime.parse(lastPosition['time'])).inSeconds < 10) return; // last element should be at least 10 seconds ago
    if(speedKmh != null && speedKmh < 0.5) return; // speed should be at least 0.5 km/h (user should be moving)
  }

  // Add to position history
  if(globals.currentDevice['stats']['positionHistory'].length > 1000) globals.currentDevice['stats']['positionHistory'].removeAt(0);
  globals.currentDevice['stats']['positionHistory'].add({
    'longitude': longitude,
    'latitude': latitude,
    'speedKmh': speedKmh ?? 0,
    'time': DateTime.now().toIso8601String()
  });

  // Filter to remove old positions (older than 20 hours)
  globals.currentDevice['stats']['positionHistory'].removeWhere((element) => DateTime.parse(element['time']).difference(DateTime.now()).inHours > 20);

  // Save in box
  globals.saveInBox();
}