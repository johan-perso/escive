import 'package:escive/utils/globals.dart' as globals;

import 'package:package_info_plus/package_info_plus.dart';

Future<Map> getAppVersion() async {
  late PackageInfo packageInfo;
  if(globals.cache.containsKey('packageInfo')) {
    packageInfo = globals.cache['packageInfo'];
  } else {
    packageInfo = await PackageInfo.fromPlatform();
    globals.cache['packageInfo'] = packageInfo;
  }

  return {
    'version': packageInfo.version,
    'build': packageInfo.buildNumber,
  };
}