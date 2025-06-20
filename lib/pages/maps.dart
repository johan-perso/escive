import 'package:escive/main.dart';
import 'package:escive/utils/geolocator.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/navigation_launcher.dart';
import 'package:escive/utils/haptic.dart';

import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as flutter_geolocator;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSubscription;
  SearchController searchController = SearchController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 400); // avoid a new request at every keystroke without waiting
  String _lastSearchQuery = '';
  List _lastSearchResults = [];
  String searchInputError = '';
  flutter_geolocator.Position? currentPosition;
  Map reversedPlaces = {};
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? destinationMarker;

  Future<Uint8List> _createDefaultMarker() async {
    const int size = 60;
    const double strokeWidth = 10.0;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, paintWhite);

    final paintRed = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, (size / 2) - strokeWidth, paintRed);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void addMarker(double longitude, double latitude) async {
    try {
      if (destinationMarker != null) await pointAnnotationManager!.delete(destinationMarker!);
    } catch (e) {
      logarte.log('Cannot delete marker: $e');
    }
    final markerImage = await _createDefaultMarker();
    final pointAnnotationOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      image: markerImage,
      iconSize: 1.0,
    );
    destinationMarker = await pointAnnotationManager!.create(pointAnnotationOptions);
  }

  MapboxMap? mapboxMap;
  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    resetCamera(instant: true);

    mapboxMap.gestures.updateSettings(GesturesSettings( // define accepted gestures
      rotateEnabled: true,
      pinchToZoomEnabled: true,
      scrollEnabled: true,
      pitchEnabled: true,
      pinchPanEnabled: true,
      doubleTapToZoomInEnabled: false
    ));

    mapboxMap.logo.updateSettings(LogoSettings(enabled: false)); // hide mapbox logo
    mapboxMap.attribution.updateSettings(AttributionSettings(position: OrnamentPosition.BOTTOM_RIGHT)); // place info icon in the bottom right
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false)); // hide the scale bar
    mapboxMap.location.updateSettings(LocationComponentSettings(enabled: true)); // current user position indicator

    pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();

    var tapInteraction = TapInteraction.onMap((context) async {
      logarte.log("User tapped on map at: lat = ${context.point.coordinates.lat}, lng = ${context.point.coordinates.lng}");

      mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(context.point.coordinates.lng, context.point.coordinates.lat)),
          zoom: 15,
        ),
        MapAnimationOptions(
          duration: 1000,
          startDelay: 0
        )
      );

      Haptic().click();
      if(mounted) setState(() { searchInputError = ''; });

      // Add marker on the map
      addMarker(context.point.coordinates.lng.toDouble(), context.point.coordinates.lat.toDouble());

      // Add current position name to the search bar
      try {
        String reversed = await reverseCoordinates(context.point.coordinates.lng.toDouble(), context.point.coordinates.lat.toDouble());
        searchController.text = reversed;
      } catch (e) {
        logarte.log('Cannot reverse geocode: $e');
        if(mounted) setState(() { searchInputError = 'maps.cannotReverseGeocode'.tr(); });
      }
    });
    mapboxMap.addInteraction(tapInteraction);
  }

  CameraOptions cameraOptions = CameraOptions(
    center: Point(coordinates: Position(2.3522, 48.8566)), // Paris
    zoom: 12,
  );

  Future<String> reverseCoordinates(double longitude, double latitude) async {
    try { // fastest way, using geocoding package (with native functions)
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '${place.street}, ${place.postalCode} ${place.locality}';

        reversedPlaces[address] = { 'longitude': longitude, 'latitude': latitude };
        reversedPlaces[address.replaceAll(' ', '')] = { 'longitude': longitude, 'latitude': latitude };
        return address;
      } else {
        logarte.log('No place found while using geocoding package: $placemarks ; we will retry with Mapbox reverse geocoding');
        throw Exception('No place found');
      }
    } catch (e) { // fallback
      final url = 'https://api.mapbox.com/search/geocode/v6/reverse'
        '?longitude=$longitude'
        '&latitude=$latitude'
        '&access_token=${dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN']!}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'].isNotEmpty) {
          final place = data['features'][0];
          final address = place['properties']['full_address'] ?? place['place_name'] ?? 'Unknown Route at $latitude, $longitude';

          reversedPlaces[address] = { 'longitude': longitude, 'latitude': latitude };
          reversedPlaces[address.replaceAll(' ', '')] = { 'longitude': longitude, 'latitude': latitude };
          return address;
        } else {
          logarte.log('No place found while using Mapbox reverse geocoding: ${response.statusCode} $data');
          throw Exception('No place found');
        }
      } else {
        logarte.log('Cannot fetch Mapbox reverse geocoding: ${response.statusCode} ${response.body}');
        throw Exception('Failed to fetch address');
      }
    }
  }

  Future<List<Map<String, dynamic>>> searchPlacesUsingMapbox(String query, BuildContext context) async {
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json'
      '?country=FR'
      '&language=${localization.EasyLocalization.of(context)!.locale.languageCode}'
      '&access_token=${dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN']!}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['features']);
    } else {
      logarte.log('Cannot fetch Mapbox places: ${response.statusCode} ${response.body}');
    }

    return [];
  }

  void resetCamera({ bool instant = false }) async {
    var currentPosition = await getCurrentPosition();
    this.currentPosition = currentPosition;

    if (instant) {
      mapboxMap?.setCamera(
        CameraOptions(center: Point(coordinates: Position(currentPosition.longitude, currentPosition.latitude)), zoom: 12)
      );
    } else {
      mapboxMap?.flyTo(
        CameraOptions(center: Point(coordinates: Position(currentPosition.longitude, currentPosition.latitude)), zoom: 12),
        MapAnimationOptions(duration: 700, startDelay: 0)
      );
    }
  }

  void addToMapsHistory(place){
    List mapsHistory = globals.box.read('mapsHistory') ?? [];
    if (mapsHistory.firstWhere((element) => element['title'] == place['title'] && element['subtitle'] == place['subtitle'] || element['query'] == place['query'], orElse: () => null) != null) {
      Map el = mapsHistory.firstWhere((element) => element['title'] == place['title'] && element['subtitle'] == place['subtitle'] || element['query'] == place['query']);
      if(place['notprecise'] == true && el['notprecise'] != true) place = el; // if the place we're adding is less precise than the one we already have, we use the old one
      mapsHistory.remove(el);
    }
    mapsHistory.insert(0, place);
    if (mapsHistory.length > 5) mapsHistory.removeLast();
    globals.box.write('mapsHistory', mapsHistory);
  }

  void startNavigation(BuildContext context, String query) async {
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    setState(() { searchInputError = ''; });
    if (query.isEmpty){
      return Haptic().click();
    }
    Haptic().light();

    // Get the coordinates of where the user wants to go
    Map? endCoords = reversedPlaces[query];
    if (endCoords == null){
      List searchResults = await autocompleteSearch(query);
      if (searchResults.isEmpty){
        if (context.mounted) setState(() { searchInputError = 'maps.noResultsFound'.tr(); });
        return;
      }

      endCoords = { 'longitude': searchResults[0]['longitude'], 'latitude': searchResults[0]['latitude'] };
    }

    addToMapsHistory({
      'title': query,
      'subtitle': endCoords['latitude']!= null && endCoords['longitude']!= null? '${endCoords['latitude']}, ${endCoords['longitude']}' : null,
      'query': query,
      'longitude': endCoords['longitude'],
      'latitude': endCoords['latitude'],
      'notprecise': true
    });

    // Place the camera at the user's current position
    resetCamera(instant: false);

    // Open the navigation app
    String destinationName = query.contains(',') ? query.split(',').first : query;
    String? destinationAddress = query.contains(',') ? query.split(',').last : null;
    bool openedNavigation = await NavigationLauncher.launchNavigation(
      startLat: currentPosition?.latitude,
      startLng: currentPosition?.longitude,
      destinationLat: endCoords['latitude'],
      destinationLng: endCoords['longitude'],
      destinationName: destinationName,
      destinationAddress: destinationAddress,
    );

    // Check if navigation cannot be opened
    if (!openedNavigation && context.mounted){
      setState(() { searchInputError = 'maps.cannotOpenNavigation'.tr(); });
      return Haptic().error();
    }
  }

  Future<List> debouncedAutocompleteSearch(String query) async {
    final Completer<List> completer = Completer<List>();
    
    _searchDebouncer.run(() async {
      try {
        final results = await autocompleteSearch(query);
        if (!completer.isCompleted) completer.complete(results);
      } catch (e) {
        if (!completer.isCompleted) completer.complete([]);
      }
    });
    
    return completer.future;
  }

  Future<List> autocompleteSearch(String query) async {
    setState(() { searchInputError = ''; });

    if (query.isEmpty || query.length < 2){
      List mapsHistory = globals.box.read('mapsHistory') ?? [];
      return mapsHistory;
    }

    if (_lastSearchQuery == query) return _lastSearchResults;
    if (_lastSearchQuery.trim() == query.trim()) return _lastSearchResults;
    _lastSearchQuery = query;

    currentPosition ??= await getCurrentPosition();
    if (!mounted) return [];

    if (dotenv.env['GEOAPIFY_API_KEY'] != null){
      final url = 'https://api.geoapify.com/v1/geocode/autocomplete?text='
        '$query'
        '&lang=${localization.EasyLocalization.of(context)!.locale.languageCode}'
        '&filter=countrycode:auto'
        '&bias=proximity:${currentPosition?.longitude},${currentPosition?.latitude}|countrycode:none'
        '&format=json'
        '&limit=5'
        '&apiKey=${dotenv.env['GEOAPIFY_API_KEY']}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map;
        if (!data.containsKey('results') || data['results'].isEmpty){
          if (context.mounted) setState(() { searchInputError = 'maps.noResultsFound'.tr(); });
          _lastSearchResults = [];
          return [];
        }

        data['results'].removeWhere((result) => result['address_line1'] == null || result['street'] == null || result['postcode'] == null || result['city'] == null || result['lon'] == null || result['lat'] == null);

        List toReturn = data['results'].map((result) => {
          'title': result['address_line1'] ?? result['name'],
          'subtitle': result['address_line2'] ?? '${result['street']}, ${result['postcode']} ${result['city']}',
          'longitude': result['lon'],
          'latitude': result['lat'],
        }).toList();

        for (var result in toReturn) {
          Map pos = { 'longitude': result['longitude'], 'latitude': result['latitude'] };
          reversedPlaces[result['title']] = pos;
          reversedPlaces[result['subtitle']] = pos;
          reversedPlaces['${result['title']}${result['subtitle']}'] = pos;
          reversedPlaces['${result['title']} ${result['subtitle']}'] = pos;
          reversedPlaces['${result['title']},${result['subtitle']}'] = pos;
          reversedPlaces['${result['title']}, ${result['subtitle']}'] = pos;
        }

        _lastSearchResults = toReturn;
        return toReturn;
      }
    }

    // Use mapbox as fallback
    if (!mounted) return [];
    final places = await searchPlacesUsingMapbox(query, context);
    if (places.isEmpty){
      if (context.mounted) setState(() { searchInputError = 'maps.noResultsFound'.tr(); });
      _lastSearchResults = [];
      return [];
    }

    for (var result in places) {
      Map pos = { 'longitude': result['longitude'], 'latitude': result['latitude'] };
      reversedPlaces[result['text']] = pos;
      reversedPlaces[result['place_name']] = pos;
      reversedPlaces['${result['text']}${result['place_name']}'] = pos;
      reversedPlaces['${result['text']} ${result['place_name']}'] = pos;
      reversedPlaces['${result['text']},${result['place_name']}'] = pos;
      reversedPlaces['${result['text']}, ${result['place_name']}'] = pos;
    }

    List toReturn = places.map((place) => {
      'title': place['text'],
      'subtitle': place['place_name'],
      'longitude': place['center'][0],
      'latitude': place['center'][1],
    }).toList();

    _lastSearchResults = toReturn;
    return toReturn;
  }

  @override
  void initState() {
    _streamSubscription = globals.socket.stream.listen((event) {
      if (event['type'] == 'refreshStates' && event['value'].contains('maps')){
        logarte.log('maps page: refreshing states');
        if (mounted) setState(() {});
      }
    });

    if (dotenv.env['GEOAPIFY_API_KEY'] == null) logarte.log("WARN dotenv GEOAPIFY_API_KEY is null");
    if (dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN'] == null) logarte.log("WARN dotenv MAPBOX_PUBLIC_ACCESS_TOKEN is null");
    MapboxOptions.setAccessToken(dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN']!);

    super.initState();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    searchController.dispose();
    _searchDebouncer.dispose();
    mapboxMap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Grab"
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  height: 3,
                  width: 112,
                  margin: const EdgeInsets.only(bottom: 28),
                ),
              ),

              // Search bar
              SearchAnchor(
                searchController: searchController,
                shrinkWrap: true,
                isFullScreen: false,
                keyboardType: TextInputType.streetAddress,
                viewOnSubmitted: (value) {
                  searchController.closeView(value);
                  startNavigation(context, value);
                },
                viewOnChanged: (value) {
                  if (destinationMarker != null && pointAnnotationManager != null) pointAnnotationManager?.delete(destinationMarker!);
                },
                builder: (BuildContext context, SearchController controller) {
                  return SearchBar(
                    controller: controller,
                    padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 16)),
                    onTapOutside: (value) => SystemChannels.textInput.invokeMethod('TextInput.hide'),
                    onSubmitted: (value) => startNavigation(context, value),
                    onChanged: (value) {
                      if (destinationMarker != null && pointAnnotationManager != null) pointAnnotationManager?.delete(destinationMarker!);
                    },
                    trailing: [
                      IconButton(
                        icon: Icon(LucideIcons.arrowUpRight),
                        color: Colors.grey[800],
                        onPressed: () => startNavigation(context, controller.text),
                      )
                    ],
                    hintText: 'maps.searchHint'.tr(),
                    onTap: () => controller.openView(),
                  );
                },
                suggestionsBuilder: (BuildContext context, SearchController controller) async {
                  final places = await debouncedAutocompleteSearch(controller.text);
                  return places.map((place) => ListTile(
                    title: Text(place['title']),
                    subtitle: Text(place['subtitle']),
                    onTap: () {
                      String controllerNewText = '${place['title']}, ${place['subtitle']}';
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                      controller.closeView(controllerNewText);
                      SystemChannels.textInput.invokeMethod('TextInput.hide');

                      place['query'] = controller.text;
                      addToMapsHistory(place);

                      mapboxMap?.flyTo(
                        CameraOptions(
                          center: Point(coordinates: Position(place['longitude'], place['latitude'])),
                          zoom: 15,
                        ),
                        MapAnimationOptions(
                          duration: 1000,
                          startDelay: 0
                        )
                      );

                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                      addMarker(place['longitude'], place['latitude']);
                      startNavigation(context, controllerNewText);
                    },
                  ));
                },
              ),

              const SizedBox(height: 6),
              AnimatedOpacity(
                opacity: searchInputError == '' ? 0 : 1,
                duration: Duration(milliseconds: 120),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    searchInputError,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Container(
                height: globals.screenHeight * 0.62,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(2, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Map
                      GestureDetector(
                        onVerticalDragUpdate: (_) {}, // avoid collision with the sheet
                        child: MapWidget(
                          key: ValueKey("mapWidget"),
                          onMapCreated: _onMapCreated,
                          cameraOptions: cameraOptions,
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
                          },
                        )
                      ),

                      // Reset camera button
                      Positioned(
                        bottom: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FloatingActionButton(
                            mini: true,
                            heroTag: 'reset_camera',
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Icon(Icons.my_location, color: Colors.white, size: 20),
                            onPressed: () {
                              Haptic().light();
                              resetCamera(instant: false);
                            }
                          ),
                        ),
                      ),
                    ]
                  )
                )
              )
            ],
          ),
        ),
      ),
    );
  }
}