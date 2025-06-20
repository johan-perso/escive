import 'package:escive/main.dart';
import 'package:escive/utils/date_formatter.dart';
import 'package:escive/utils/globals.dart' as globals;

bool isRefreshingAdvancedStats = false;
DateTime lastAdvancedStatsRefresh = DateTime.fromMillisecondsSinceEpoch(0);

void refreshAdvancedStats(){
  if(globals.settings['useAdvancedStats'] != true) return; // check if advanced stats are enabled
  if(globals.currentDevice.isEmpty) return; // check if we're connected
  if(!globals.currentDevice.containsKey('currentActivity') || globals.currentDevice['currentActivity']['state'] == 'none') return; // check if we're connected
  if(!globals.currentDevice.containsKey('stats')) return; // check if current device has stats map

  DateTime now = DateTime.now();
  Map globalsStats = globals.currentDevice['stats'];

  if(isRefreshingAdvancedStats && now.difference(lastAdvancedStatsRefresh).inMinutes < 5) return; // avoid refreshing if already refreshing, we check time in case there's a bug and we never redefine the refresh state
  if(now.difference(lastAdvancedStatsRefresh).inSeconds < 55) return; // check if we're not refreshing too often (55 seconds)

  isRefreshingAdvancedStats = true;
  lastAdvancedStatsRefresh = now;

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
        print("Added ${globalsStats['datas']['allDaysDistanceKm'][currentDayInYear]}km to week distance");
      } catch(e){
        weekDistanceKm += double.tryParse(globalsStats['datas']['allDaysDistanceKm'][currentDayInYear].toString()) ?? 0;
        print("Added ${globalsStats['datas']['allDaysDistanceKm'][currentDayInYear]}km to week distance");
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