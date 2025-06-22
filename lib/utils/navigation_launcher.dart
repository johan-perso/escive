import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationLauncher {
  // Navigation on Android
  static Future<bool> _launchAndroidNavigation({
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    String? destinationAddress,
  }) async {
    List urls = [];

    urls.add('google.navigation:q=$destinationLat,$destinationLng&mode=b'); // Google Maps
    urls.add('transit://directions?to=$destinationLat,$destinationLng&mode=bike'); // Transit
    urls.add('citymapper://directions?endcoord=$destinationLat,$destinationLng${destinationName == null ? '' : '&endname=$destinationName'}${destinationAddress == null ? '' : '&endaddress=$destinationAddress'}&travel_type=cycle'); // Citymapper

    // Try to open each URL
    for (String url in urls) {
      if (await canLaunchUrl(Uri.parse(url))) return await launchUrl(Uri.parse(url));
    }
    return false;
  }

  // Navigation on iOS
  static Future<bool> _launchIOSNavigation({
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    String? destinationAddress,
  }) async {
    List urls = [];

    urls.add('comgooglemaps://?daddr=$destinationLat,$destinationLng&directionsmode=bicycling'); // Google Maps
    urls.add('maps://?daddr=$destinationLat,$destinationLng&dirflg=b'); // Apple Maps (Protocol, discontinued?)
    urls.add('transit://directions?to=$destinationLat,$destinationLng&mode=bike'); // Transit
    urls.add('citymapper://directions?endcoord=$destinationLat,$destinationLng${destinationName == null ? '' : '&endname=$destinationName'}${destinationAddress == null ? '' : '&endaddress=$destinationAddress'}'); // Citymapper
    urls.add('strava://routes/new?destination_lat=$destinationLat&destination_lng=$destinationLng'); // Strava
    urls.add('https://maps.apple.com/?ll=$destinationLat,$destinationLng${destinationName == null ? '' : '&q=$destinationName'}&dirflg=b&mode=cycling'); // Apple Maps (Web)

    // Try to open each URL
    for (String url in urls) {
      if (await canLaunchUrl(Uri.parse(url))) return await launchUrl(Uri.parse(url));
    }
    return false;
  }

  // Navigation on WEB
  static Future<bool> _launchWebNavigation({
    required double destinationLat,
    required double destinationLng,
    double? startLat,
    double? startLng,
  }) async {
    String googleMapsWebUrl = 'https://www.google.com/maps/dir/?api=1';

    if (startLat != null && startLng != null) googleMapsWebUrl += '&origin=$startLat,$startLng'; // add start point
    googleMapsWebUrl += '&destination=$destinationLat,$destinationLng&travelmode=bicycling'; // add end point

    await launchUrl(Uri.parse(googleMapsWebUrl), mode: LaunchMode.externalApplication);
    return true;
  }

  // Universal call
  static Future<bool> launchNavigation({
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    String? destinationAddress,
    double? startLat,
    double? startLng,
  }) async {
    // Sanitize
    if (destinationName != null) destinationName = Uri.encodeComponent(destinationName);
    if (destinationAddress != null) destinationAddress = Uri.encodeComponent(destinationAddress);


    if (Platform.isAndroid) {
      return await _launchAndroidNavigation(
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        destinationName: destinationName,
        destinationAddress: destinationAddress,
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      return await _launchIOSNavigation(
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        destinationName: destinationName,
        destinationAddress: destinationAddress,
      );
    } else {
      return await _launchWebNavigation(
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        startLat: startLat,
        startLng: startLng,
      );
    }
  }
}