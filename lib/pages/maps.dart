import 'package:escive/main.dart';
import 'package:escive/utils/actions_dialog.dart';
import 'package:escive/utils/geolocator.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/icon_from_string.dart';
import 'package:escive/utils/navigation_launcher.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/create_default_marker.dart';
import 'package:escive/widgets/settings_tile.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as flutter_geolocator;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:easy_localization/easy_localization.dart' as localization;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

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
  PointAnnotation? currentlyPinnedMarker;
  List<PointAnnotation> favoritesPlacesMarkers = [];
  List<PointAnnotation> trackPointMarkers = [];
  int? _animatingFavoriteIndex;
  late AnimationController _pressAnimationController;
  late Animation<double> _scaleAnimation;
  final mapBoundaryKey = GlobalKey();

  List<List<Map>> createTrackSegments(List<Map> positions) {
    List<List<Map>> segments = [];
    List<Map> currentSegment = [];

    const double maxDistanceThreshold = 200; // Max distance between two points (200m)

    for (int i = 0; i < positions.length; i++) {
      currentSegment.add(positions[i]);

      if (i < positions.length - 1) {
        var current = positions[i];
        var next = positions[i + 1];

        // Determine distance between current and next point
        double distance = flutter_geolocator.Geolocator.distanceBetween(
          current['latitude'], current['longitude'],
          next['latitude'], next['longitude']
        );

        // If distance is greater than the threshold, create a new segment
        if (distance > maxDistanceThreshold) {
          if (currentSegment.length > 1) {
            segments.add(List.from(currentSegment));
          }
          currentSegment.clear();
        }
      }
    }

    // Add the last segment if it's not empty
    if (currentSegment.length > 1) segments.add(currentSegment);

    return segments;
  }

  String positionHistoryToGeoJson() {
    // Prevent trying to parse empty history
    if (!globals.currentDevice.containsKey('stats') || !globals.currentDevice['stats'].containsKey('positionHistory') || globals.currentDevice['stats']['positionHistory'].isEmpty) return '{"type": "FeatureCollection", "features": []}';

    List<Map> positions = List<Map>.from(globals.currentDevice['stats']['positionHistory']);
    if (positions.length < 2) return '{"type": "FeatureCollection", "features": []}'; // at least 2 points are needed to create a line

    // Create segments of points (based on their distances)
    List<List<Map>> segments = createTrackSegments(positions);
    List<Map<String, dynamic>> features = [];

    // Create a list of features with coordinates and speed
    for (int segmentIndex = 0; segmentIndex < segments.length; segmentIndex++) {
      List<Map> segment = segments[segmentIndex];

      if (segment.length < 2) continue;

      // Create a list of coordinates for this segment
      List<List<double>> coordinates = [];
      for (var position in segment) {
        coordinates.add([position['longitude'], position['latitude']]);
      }

      // Average speed for this segment
      double avgSpeed = 0;
      if (segment.isNotEmpty && segment[0].containsKey('speedKmh')) {
        double totalSpeed = 0;
        int validSpeedCount = 0;

        for (var pos in segment) {
          if (pos.containsKey('speedKmh') && pos['speedKmh'] != null) {
            totalSpeed += pos['speedKmh'];
            validSpeedCount++;
          }
        }

        if (validSpeedCount > 0) avgSpeed = totalSpeed / validSpeedCount;
      }

      features.add({
        "type": "Feature",
        "properties": {
          "speed": avgSpeed,
          "segmentIndex": segmentIndex,
          "pointCount": segment.length,
        },
        "geometry": {
          "type": "LineString",
          "coordinates": coordinates
        }
      });
    }

    return jsonEncode({
      "type": "FeatureCollection",
      "features": features
    });
  }

  Future<void> displayTrackOnMap(MapboxMap mapboxMap) async {
    // Check if we have a position history
    if (!globals.currentDevice.containsKey('stats') || !globals.currentDevice['stats'].containsKey('positionHistory') || globals.currentDevice['stats']['positionHistory'].isEmpty) return;

    String geoJsonData = positionHistoryToGeoJson();
    if(globals.settings['showDebugTrackPoints'] == true) await displayTrackPointsAsMarkers();

    // Check if source is existing
    bool hasTrackSource = false;
    try {
      await mapboxMap.style.getSource("track-source");
      hasTrackSource = true;
    } catch (e) {
      // source isn't existing
    }

    if (hasTrackSource) { // if we already have a track source, update it
      List<Position> positions = globals.currentDevice['stats']['positionHistory'].map<Position>((point) => 
        Position(point['longitude'], point['latitude'])
      ).toList();

      var feature = Feature(
        id: "track-feature-id", // Unique ID for the feature
        geometry: LineString(coordinates: positions)
      );

      await mapboxMap.style.updateGeoJSONSourceFeatures(
        "track-source",
        "track-data",
        [feature]
      );
    } else {
      // Else, we need to create one
      await mapboxMap.style.addSource(GeoJsonSource(
        id: "track-source",
        data: geoJsonData,
      ));

      // Add a layer with speed-based colors
      await mapboxMap.style.addLayer(LineLayer(
        id: "track-layer",
        sourceId: "track-source",
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineWidth: 4.0,
        lineColorExpression: [
          'interpolate',
          ['linear'],
          ['get', 'speed'], // Based on speed property
          0, ['rgb', 76, 175, 80],    // Colors.green
          9, ['rgb', 205, 220, 57],   // Colors.lime
          18, ['rgb', 255, 235, 59],  // Colors.yellow
          24, ['rgb', 255, 152, 0],   // Colors.orange
          34, ['rgb', 255, 87, 34],   // Colors.deepOrange
          40, ['rgb', 244, 67, 54]    // Colors.red
        ],
      ));
    }
  }

  Future<void> displayTrackPointsAsMarkers() async {
    // Remove existing markers
    try {
      for (var marker in trackPointMarkers) {
        await pointAnnotationManager!.delete(marker);
      }
      trackPointMarkers.clear();
    } catch (e) {
      logarte.log('Cannot delete track point markers: $e');
    }

    List<Map> positions = List<Map>.from(globals.currentDevice['stats']['positionHistory']);

    // Create a new marker for each coordinate (max 60 to avoid performance issues)
    int step = positions.length > 60 ? (positions.length / 60).ceil() : 1;

    for (int i = 0; i < positions.length; i += step) {
      var position = positions[i];

      final pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(position['longitude'], position['latitude'])),
        iconSize: 1,
        isDraggable: false,
        textField: '${i + 1}', // Display the index + 1
        textOffset: [0, -1.5],
        textSize: 15,
        textColor: Colors.black.toARGB32(),
      );
      
      final marker = await pointAnnotationManager!.create(pointAnnotationOptions);
      trackPointMarkers.add(marker);
    }
  }

  void editFavorite(BuildContext context, String? name, int index, String? action) async {
    setState(() { searchInputError = ''; });
    Haptic().light();

    if(action == null){
      List choices = [
        {
          "id": "rename",
          "title": "maps.favorite.actions.rename.label".tr()
        },
        {
          "id": "changeicon",
          "title": "maps.favorite.actions.changeicon.label".tr()
        },
        {
          "id": "repin",
          "title": "maps.favorite.actions.repin".tr()
        },
        {
          "id": "delete",
          "title": "maps.favorite.actions.delete".tr()
        },
      ];

      return showSelectModal(
        context: context,
        title: 'maps.favorite.actions.prompt'.tr(),
        values: choices,
        onChanged: (value) async {
          String action = choices[value]['id'];
          logarte.log('User selected option $action on item with index = $index ; name = $name');
          return editFavorite(context, name, index, action);
        }
      );
    } else if(action == 'rename'){
      final TextEditingController favoriteNameController = TextEditingController();
      favoriteNameController.text = name ?? '';

      await Future.delayed(Duration(milliseconds: 90)); // wait for the modal to close
      if(!context.mounted) return;

      actionsDialog(
        context,
        title: 'maps.favorite.actions.rename.dialogTitle'.tr(),
        content: 'maps.favorite.actions.rename.dialogContent'.tr(),
        haptic: 'light',
        actionsPadding: const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 10),
        actions: [
          TextField(
            controller: favoriteNameController,
            decoration: InputDecoration(
              border: UnderlineInputBorder(),
              hintText: name ?? 'maps.favorite.notDefined'.tr(),
              hintStyle: TextStyle(color: Colors.grey[400])
            ),
          ),

          SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
                child: Text('general.cancel'.tr()),
                onPressed: () {
                  Haptic().light();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.blue[500]),
                child: Text('general.confirm'.tr()),
                onPressed: () {
                  List favoritesPlaces = (globals.settings['favoritesPlaces'] ?? [{},{},{}]);
                  favoritesPlaces[index]['name'] = favoriteNameController.text.trim().isEmpty ? null : favoriteNameController.text.trim();
                  globals.setSettings('favoritesPlaces', favoritesPlaces);
                  Navigator.of(context).pop();
                  Haptic().success();

                  setFavoritesPlacesMarkers();

                  Timer(Duration(seconds: 1), () {
                    favoriteNameController.dispose();
                  });
                },
              ),
            ],
          ),
        ]
      );
    } else if(action == 'changeicon'){
      await Future.delayed(Duration(milliseconds: 90)); // wait for the modal to close
      if(!context.mounted) return;

      List allIcons = iconsMap.entries.map((entry) {
        if (entry.key == 'default' || entry.key == 'question') return null;

        return {
          'id': entry.key,
          'icon': entry.value,
        };
      }).toList();
      allIcons.removeWhere((item) => item == null);

      await showMaterialModalBottomSheet(
        duration: const Duration(milliseconds: 300),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
        context: context,
        builder: (context) {
          return Material(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8, // Hauteur max seulement
              ),
              padding: const EdgeInsets.only(left: 12, right: 18, top: 14, bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center( // "Grab"
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).hintColor,
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      height: 3,
                      width: 112,
                      margin: const EdgeInsets.only(bottom: 24),
                    ),
                  ),

                  Text(
                    'maps.favorite.actions.changeicon.dialogTitle'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  SizedBox(height: 16),

                  // Icons grid
                  Flexible(
                    child: GridView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, // 5 columns
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: allIcons.length,
                      itemBuilder: (context, iconIndex) {
                        return GestureDetector(
                          onTap: () {
                            List favoritesPlaces = (globals.settings['favoritesPlaces'] ?? [{},{},{}]);
                            favoritesPlaces[index]['icon'] = allIcons[iconIndex]['id'];
                            globals.setSettings('favoritesPlaces', favoritesPlaces);

                            Navigator.of(context).pop();
                            Haptic().success();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                allIcons[iconIndex]['icon'],
                                size: 28,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 14),
                ],
              ),
            ),
          );
        }
      );
    } else if(action == 'repin'){
      if(currentlyPinnedMarker == null){
        setState(() { searchInputError = 'maps.favorite.noPinnedPoint'.tr(); });
        return Haptic().warning();
      }

      double pinLongitude = currentlyPinnedMarker!.geometry.coordinates.lng.toDouble();
      double pinLatitude = currentlyPinnedMarker!.geometry.coordinates.lat.toDouble();

      reversedPlaces[name] = { 'longitude': pinLongitude, 'latitude': pinLatitude };
      List favoritesPlaces = (globals.settings['favoritesPlaces'] ?? [{},{},{}]);
      favoritesPlaces[index]['longitude'] = pinLongitude;
      favoritesPlaces[index]['latitude'] = pinLatitude;
      globals.setSettings('favoritesPlaces', favoritesPlaces);
      setFavoritesPlacesMarkers();
      return Haptic().success();
    } else if(action == 'delete'){
      List favoritesPlaces = (globals.settings['favoritesPlaces']?? [{},{},{}]);
      favoritesPlaces[index] = {};
      globals.setSettings('favoritesPlaces', favoritesPlaces);
      setFavoritesPlacesMarkers();
      return Haptic().success();
    }
  }

  void _stopFavoriteContainerAnimation() {
    setState(() => _animatingFavoriteIndex = null);
    _pressAnimationController.stop();
    _pressAnimationController.reset();
  }

  Widget _buildFavoriteContainer(BuildContext context, { String? name, String? icon, int index = 0, double? longitude, double? latitude }) {
    bool isAnimating = _animatingFavoriteIndex == index;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
      double scale = isAnimating ? _scaleAnimation.value : 1.0;

      return Transform.scale(
        scale: scale,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: isAnimating ? 0.6 : 0.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isAnimating ? 0.3 : 0.2),
                spreadRadius: isAnimating ? 2 : 1,
                blurRadius: isAnimating ? 8 : 5,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) {
              setState(() => _animatingFavoriteIndex = index);
              _pressAnimationController.repeat(reverse: true);
              Haptic().light();
            },
            onTapUp: (_) => _stopFavoriteContainerAnimation(),
            onTapCancel: () => _stopFavoriteContainerAnimation(),
            onTap: () { // set search input to the address
              if(longitude == null || latitude == null) return editFavorite(context, name, index, null);

              if(searchController.text == name || searchController.text == '$longitude, $latitude') return startNavigation(context, name ?? '$longitude, $latitude');

              tapHandlerPin(name, longitude, latitude);
              _stopFavoriteContainerAnimation();
            },
            onDoubleTap: () { // set search input to the address, and start navigation
              if(longitude == null || latitude == null || name == null) return Haptic().warning();

              tapHandlerPin(name, longitude, latitude);
              _stopFavoriteContainerAnimation();
              Timer(Duration(milliseconds: 350), () {
                startNavigation(context, name);
              });
            },
            onLongPress: () { // edit the favorite
              _stopFavoriteContainerAnimation();
              editFavorite(context, name, index, null);
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Icon(
                      iconFromString(icon ?? 'default'),
                      color: Colors.grey[100],
                      size: 26,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          offset: Offset(0, 0),
                          blurRadius: 1,
                        ),
                      ],
                    )
                  ),
                  Positioned(
                    bottom: 6,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 9, right: 7),
                      child: Text(
                        name ?? 'maps.favorite.notDefined'.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontFamily: 'Sora',
                          color: Colors.grey[100],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              offset: Offset(0, 0),
                              blurRadius: 3,
                            ),
                          ]
                        ),
                      ),
                    )
                  )
                ]
              )
            )
          )
        )
      );
    });
  }

  void tapHandlerPin(String? name, double longitude, double latitude){
    Haptic().light();
    setState(() { searchInputError = ''; });
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    reversedPlaces[name] = { 'longitude': longitude, 'latitude': latitude };
    reversedPlaces['$longitude, $latitude'] = { 'longitude': longitude, 'latitude': latitude };
    setCurrentlyPinnerMarker(longitude, latitude);
    searchController.text = name ?? '$longitude, $latitude';

    mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 15,
      ),
      MapAnimationOptions(
        duration: 1000,
        startDelay: 0
      )
    );
  }

  void setCurrentlyPinnerMarker(double longitude, double latitude) async {
    try {
      if (currentlyPinnedMarker != null) await pointAnnotationManager!.delete(currentlyPinnedMarker!);
    } catch (e) {
      logarte.log('setCurrentlyPinnerMarker: Cannot delete marker: $e');
    }
    final markerImage = await createDefaultMarker(Colors.red);
    final pointAnnotationOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      image: markerImage,
      iconSize: 1.0,
      isDraggable: false
    );
    currentlyPinnedMarker = await pointAnnotationManager!.create(pointAnnotationOptions);
  }

  void setFavoritesPlacesMarkers() async {
    try {
      for (var marker in favoritesPlacesMarkers) {
        await pointAnnotationManager!.delete(marker);
      }
    } catch (e) {
      logarte.log('setFavoritesPlacesMarkers: Cannot delete marker: $e');
    }

    final markerImage = await createDefaultMarker(Colors.yellow);

    favoritesPlacesMarkers = [];
    List favoritesPlaces = (globals.settings['favoritesPlaces']?? [{},{},{}]);
    for (var favorite in favoritesPlaces) {
      if(favorite['longitude'] == null || favorite['latitude'] == null) continue;
      final pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(favorite['longitude'], favorite['latitude'])),
        image: markerImage,
        iconSize: 1.0,
        textField: favorite['name'],
        textOffset: [0, 1.5],
        textSize: 13,
        isDraggable: false,
        textMaxWidth: 18,
        textEmissiveStrength: 1,
      );
      final marker = await pointAnnotationManager!.create(pointAnnotationOptions);
      favoritesPlacesMarkers.add(marker);
    }
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
    setFavoritesPlacesMarkers();

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
      setCurrentlyPinnerMarker(context.point.coordinates.lng.toDouble(), context.point.coordinates.lat.toDouble());

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

  _onStyleLoadedCallback(StyleLoadedEventData data) async {
    await displayTrackOnMap(mapboxMap!);
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

  void resetCamera({ bool instant = false, double zoom = 12 }) async {
    var currentPosition = await getCurrentPosition(null);
    this.currentPosition = currentPosition;

    if (instant) {
      mapboxMap?.setCamera(CameraOptions(center: Point(coordinates: Position(currentPosition.longitude, currentPosition.latitude)), zoom: zoom));
    } else {
      mapboxMap?.flyTo(
        CameraOptions(center: Point(coordinates: Position(currentPosition.longitude, currentPosition.latitude)), zoom: zoom),
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

    currentPosition ??= await getCurrentPosition(flutter_geolocator.LocationAccuracy.low);
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

    if(globals.settings['favoritesPlaces'] == null) globals.setSettings('favoritesPlaces', [{}, {}, {}]);
    if(globals.settings['favoritesPlaces'].length != 3) globals.setSettings('favoritesPlaces', [{}, {}, {}]);

    if (dotenv.env['GEOAPIFY_API_KEY'] == null) logarte.log("WARN dotenv GEOAPIFY_API_KEY is null");
    if (dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN'] == null) logarte.log("WARN dotenv MAPBOX_PUBLIC_ACCESS_TOKEN is null");
    MapboxOptions.setAccessToken(dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN']!);

    _pressAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _pressAnimationController,
      curve: Curves.easeInOut,
    ));

    super.initState();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    searchController.dispose();
    _searchDebouncer.dispose();
    _pressAnimationController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureMapWithCustomText() async {
    final snapshot = await mapboxMap!.snapshot();
    final codec = await ui.instantiateImageCodec(snapshot);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(originalImage, Offset.zero, Paint());

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'eScive',
        style: TextStyle(
          fontSize: 50,
          color: mounted ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9) : Colors.blue[700]!,
          fontWeight: FontWeight.bold,
          fontFamily: 'Sora',
          shadows: [
            Shadow(
              color: Colors.black,
              offset: Offset(0, 0),
              blurRadius: mounted ? 1 : 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final textY = originalImage.height - textPainter.height - 20;
    textPainter.paint(canvas, Offset(30, textY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      originalImage.width,
      originalImage.height,
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Widget _buildSearchBar(BuildContext context){
    return Column(
      children: [
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
            if (currentlyPinnedMarker != null && pointAnnotationManager != null) pointAnnotationManager?.delete(currentlyPinnedMarker!);
          },
          builder: (BuildContext context, SearchController controller) {
            return SearchBar(
              controller: controller,
              padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 16)),
              onTapOutside: (value) => SystemChannels.textInput.invokeMethod('TextInput.hide'),
              onSubmitted: (value) => startNavigation(context, value),
              onChanged: (value) {
                if (currentlyPinnedMarker != null && pointAnnotationManager != null) pointAnnotationManager?.delete(currentlyPinnedMarker!);
              },
              trailing: [
                IconButton(
                  icon: Icon(LucideIcons.arrowUpRight),
                  color: Colors.grey[700],
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
                setCurrentlyPinnerMarker(place['longitude'], place['latitude']);
                startNavigation(context, controllerNewText);
              },
            ));
          },
        ),

        // Error message (invisible if not defined)
        const SizedBox(height: 6),
        AnimatedOpacity(
          opacity: searchInputError == '' ? 0 : 1,
          duration: Duration(milliseconds: 101),
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
      ]
    );
  }

  Widget _buildShortcuts(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12,
      children: (globals.settings['favoritesPlaces'] ?? []).asMap().entries.map<Widget>((entry) => Expanded(
        flex: 1,
        child: _buildFavoriteContainer(
          context,
          name: entry.value['name'],
          icon: entry.value['icon'],
          index: entry.key,
          longitude: entry.value['longitude'],
          latitude: entry.value['latitude']
        ),
      )).toList(),
    );
  }

  Widget _buildMap(){
    return Container(
      height: globals.screenHeight * 0.55,
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
      child: RepaintBoundary(
        key: mapBoundaryKey,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Map
              GestureDetector(
                onVerticalDragUpdate: (_) {}, // avoid collision with the sheet
                child: MapWidget(
                  key: ValueKey("mapScreen"),
                  onMapCreated: _onMapCreated,
                  onStyleLoadedListener: _onStyleLoadedCallback,
                  cameraOptions: cameraOptions,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
                  },
                )
              ),

              // Reset camera button / hidden share
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onLongPress: () async {
                      Haptic().light();
                      logarte.log('ExportMap: capturing map image...');
                      Uint8List? bytes = await _captureMapWithCustomText();
                      logarte.log('ExportMap: captured map image, bytes length: ${bytes?.length ?? 0}');
                      if (!mounted) return;

                      if (bytes == null || bytes.isEmpty) {
                        logarte.log('ExportMap: failed to capture map image, got zero bytes');
                        if (mounted) setState(() { searchInputError = 'maps.cannotCaptureMapImage'.tr(); });
                        return;
                      }

                      logarte.log('ExportMap: saving map image...');
                      final directory = await getTemporaryDirectory();
                      final file = File('${directory.path}/map_screenshot_${DateTime.now().millisecondsSinceEpoch}.png');
                      await file.writeAsBytes(bytes);
                      logarte.log('ExportMap: saved as ${file.path}');

                      final shareResult = await SharePlus.instance.share(ShareParams(
                        files: [ XFile(file.path) ],
                      ));
                      logarte.log('ExportMap: shared map image, result: $shareResult');
                    },
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'reset_camera',
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(Icons.my_location, color: Colors.white, size: 20),
                      onPressed: () {
                        Haptic().light();
                        resetCamera(instant: false, zoom: 18);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(left: globals.isLandscape ? 24 : 18, right: globals.isLandscape ? 24 : 18, top: 14, bottom: 16),
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

              globals.isLandscape
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildSearchBar(context),
                        const SizedBox(height: 6),
                        _buildShortcuts(),
                      ]
                    )
                  ),

                  const SizedBox(width: 28),

                  Expanded(child: _buildMap()),
                ],
              )
              : Column(
                children: [
                   // Search bar
                  _buildSearchBar(context),
                  const SizedBox(height: 8),

                  // Shortcuts to favorites places
                  _buildShortcuts(),
                  const SizedBox(height: 14),

                  // Map
                  _buildMap(),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}