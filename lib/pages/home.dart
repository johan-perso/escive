import 'package:escive/main.dart';
import 'package:escive/pages/add_device.dart';
import 'package:escive/pages/maps.dart';
import 'package:escive/pages/music_player.dart';
import 'package:escive/pages/settings.dart';
import 'package:escive/utils/changelog.dart';
import 'package:escive/utils/geolocator.dart';
import 'package:escive/utils/get_app_version.dart';
import 'package:escive/utils/date_formatter.dart';
import 'package:escive/utils/actions_dialog.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/refresh_advanced_stats.dart';
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/utils/create_default_marker.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/widgets/artwork.dart';
import 'package:escive/widgets/battery_indicator.dart';
import 'package:escive/widgets/speed_mode_selector.dart';
import 'package:escive/widgets/speedometer.dart';
import 'package:escive/widgets/warning_light.dart';

import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as flutter_rendering;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:action_slider/action_slider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as flutter_geolocator;
import 'package:easy_localization/easy_localization.dart' as localization;

GlobalKey deviceNameWidget = GlobalKey();
final TextEditingController _deviceNameController = TextEditingController();

class EsciveMapWidget extends StatefulWidget {
  const EsciveMapWidget({super.key});

  @override
  State<EsciveMapWidget> createState() => _EsciveMapWidgetState();
}

class _EsciveMapWidgetState extends State<EsciveMapWidget> {
  flutter_geolocator.Position? currentPosition;
  Timer? forceRefreshPositionTimer;
  Timer? refreshCameraTimer;
  bool isCurrentLocationAvailable = false;
  String street = '';
  String city = '';
  PointAnnotationManager? pointAnnotationManager;
  List<PointAnnotation> favoritesPlacesMarkers = [];

  CameraOptions defaultCameraOptions = CameraOptions(
    center: Point(coordinates: Position(2.3522, 48.8566)), // Paris
    zoom: 12,
    padding: MbxEdgeInsets(
      left: 16,
      right: 16,
      top: 16,
      bottom: 16
    )
  );

  MapboxMap? mapboxMap;
  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    mapboxMap.logo.updateSettings(LogoSettings(enabled: false)); // hide mapbox logo
    mapboxMap.attribution.updateSettings(AttributionSettings(enabled: false)); // hide info icon
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false)); // hide the scale bar
    mapboxMap.location.updateSettings(LocationComponentSettings(enabled: true)); // current user position indicator
    mapboxMap.style.setStyleImportConfigProperty("basemap", "show3dObjects", false); // disable 3D buildings

    Map currentPosition = await refreshPosition();
    if(currentPosition['latitude'].toString() != '0' && currentPosition['longitude'].toString() != '0'){
      mapboxMap.setCamera(CameraOptions(center: Point(coordinates: Position(currentPosition['longitude'], currentPosition['latitude'])), zoom: 12));
    }

    pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    setFavoritesPlacesMarkers();
  }

  void setFavoritesPlacesMarkers() async {
    try {
      for (var marker in favoritesPlacesMarkers) {
        await pointAnnotationManager!.delete(marker);
      }
    } catch (e) {
      logarte.log('setFavoritesPlacesMarkers from home: Cannot delete marker: $e');
    }

    final markerImage = await createDefaultMarker(Colors.yellow);

    favoritesPlacesMarkers = [];
    List favoritesPlaces = (globals.settings['favoritesPlaces']?? [{},{},{}]);
    for (var favorite in favoritesPlaces) {
      if(favorite['longitude'] == null || favorite['latitude'] == null) continue;
      final pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(favorite['longitude'], favorite['latitude'])),
        image: markerImage,
        iconSize: 0.8,
        textField: favorite['name'],
        textOffset: [0, 1.5],
        textSize: 11,
        isDraggable: false,
        textMaxWidth: 14,
        textEmissiveStrength: 1,
      );
      final marker = await pointAnnotationManager!.create(pointAnnotationOptions);
      favoritesPlacesMarkers.add(marker);
    }
  }

  Future<Map> refreshPosition() async {
    flutter_geolocator.Position? currentPosition;
    try {
      currentPosition = await getCurrentPosition();
      this.currentPosition = currentPosition;
    } catch (e) {
      logarte.log("refreshPosition() from home: Error while getting current position: $e");
      isCurrentLocationAvailable = false;
      return {
        'latitude': 0,
        'longitude': 0,
      };
    }

    updateGeocodedPosition(currentPosition.latitude, currentPosition.longitude);

    return {
      'latitude': currentPosition.latitude,
      'longitude': currentPosition.longitude,
    };
  }

  void resetCurrentLocation(){
    setState(() {
      street = '';
      city = '';
    });

    setState(() { // one after the other, to make sure the animation is smooth
      isCurrentLocationAvailable = false;
    });
  }

  void updateGeocodedPosition(double? latitude, double? longitude) async { // will be called after socket data is received
    if(latitude == null || longitude == null) return resetCurrentLocation();

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          street = place.street ?? '';
          city = place.locality ?? '';
        });
      } else {
        logarte.log("updateGeocodedPosition() from home: No placemark found");
        resetCurrentLocation();
      }
    } catch (e) {
      logarte.log("updateGeocodedPosition() from home: Error while getting placemark: $e");
      resetCurrentLocation();
    }

    setState(() {
      isCurrentLocationAvailable = city != '';
    });
  }

  @override
  void initState() {
    if (dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN'] == null) logarte.log("WARN dotenv MAPBOX_PUBLIC_ACCESS_TOKEN is null");
    MapboxOptions.setAccessToken(dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN']!);

    super.initState();

    if(forceRefreshPositionTimer != null) forceRefreshPositionTimer!.cancel();
    forceRefreshPositionTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      refreshPosition();
      setFavoritesPlacesMarkers();
    });

    if(refreshCameraTimer != null) refreshCameraTimer!.cancel();
    refreshCameraTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      var layer = Platform.isAndroid ? await mapboxMap?.style.getLayer("mapbox-location-indicator-layer") : await mapboxMap?.style.getLayer("puck");
      if(layer == null || (layer as LocationIndicatorLayer).location == null) return;
      var loc = layer.location!;
      if(loc.length < 2) return;
      Position position = Position(loc[1]!, loc[0]!);
      mapboxMap?.flyTo(CameraOptions(center: Point(coordinates: position)), MapAnimationOptions(duration: 500, startDelay: 0));
    });
  }

  @override
  void dispose() {
    refreshCameraTimer?.cancel();
    forceRefreshPositionTimer?.cancel();
    mapboxMap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1/1,
      child: GestureDetector(
        onTap: () async {
          var locationPermission = await checkLocationPermission();
          if(locationPermission != true) {
            Haptic().warning();
            if(context.mounted) showSnackBar(context, locationPermission, icon: 'warning');
            return;
          }

          if(!context.mounted) return;

          Haptic().light();
          refreshPosition();
          await showMaterialModalBottomSheet(
            duration: const Duration(milliseconds: 300),
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
            context: context,
            builder: (context) {
              return MapsScreen();
            },
          );
          Haptic().light();
        },
        child: Container(
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
              fit: flutter_rendering.StackFit.expand,
              children: [
                // Map
                AbsorbPointer( // disable interactions on the map
                  child: MapWidget(
                    key: ValueKey("mapWidget"),
                    onMapCreated: _onMapCreated,
                    cameraOptions: defaultCameraOptions,
                  ),
                ),

                // Current location name
                AnimatedOpacity(
                  opacity: isCurrentLocationAvailable ? 1 : 0,
                  duration: Duration(milliseconds: 200),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(street, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Sora', color: Colors.grey[200], fontWeight: FontWeight.w500, fontSize: street.length > 20 ? 12 : 13)),
                                    Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Sora', color: Colors.white, fontWeight: FontWeight.w600, fontSize: city.length > 12 ? 14 : 15))
                                  ]
                                )
                              )
                            ),
                          ),
                        ),
                      )
                    ]
                  ),
                ),
              ]
            )
          ),
        )
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool initializedBridge = false;
  bool ledTurnedOn = false;
  // bool ledAnimating = false;
  // Timer? _ledTimer;
  bool isLocked = false;
  late DateTime startTime;
  late Timer _everyDemiMinuteTimer;
  late Timer _everyQuarterMinuteTimer;
  StreamSubscription? _streamSubscription;
  final GlobalKey<_EsciveMapWidgetState> _mapWidgetKey = GlobalKey<_EsciveMapWidgetState>();

  Widget buildBasicCard(BuildContext context, { String title = 'N/A', dynamic content = 'N/A', String? hint, String contentType = 'text', double? height, String animation = '', bool transparentBackground = false }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(title, style: TextStyle(fontSize: 17, color: Colors.grey[900], fontWeight: FontWeight.normal)),
        ),

        SizedBox(
        // AnimatedContainer(
          // duration: Duration(milliseconds: 300),
          height: height,
          // decoration: BoxDecoration(
          //   boxShadow: animation == 'ledShadow' ? [
          //     BoxShadow(
          //       color: Colors.yellow[200]!,
          //       offset: Offset(0, 2),
          //       blurRadius: 32,
          //       spreadRadius: 10,
          //     ),
          //   ] : [],
          // ),
          child: Card(
            elevation: 5,
            shadowColor: transparentBackground ? Colors.transparent : animation == 'ledShadow' ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.8),
            color: transparentBackground ? Colors.transparent : Theme.of(context).cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onTap: () {
                if(hint == null) return;
                Haptic().light();
                showSnackBar(context, hint, icon: "info");
              },
              child: Container(
                padding: contentType == 'text' ? EdgeInsets.symmetric(horizontal: 6, vertical: 18) : EdgeInsets.all(4),
                child: contentType == 'text'
                  ? Text(content.toString(), style: TextStyle(fontSize: 22, color: Colors.grey[800], fontWeight: FontWeight.normal), textAlign: TextAlign.center)
                  : content is Widget ? content : const SizedBox()
              ),
            ),
          )
        )
      ],
    );
  }

  Future<void> showContextMenu(BuildContext context, Offset offset) async {
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy,
      MediaQuery.of(context).size.width - offset.dx,
      MediaQuery.of(context).size.height - offset.dy,
    );

    List devicesItems = [];
    for (var device in globals.devices) {
      String stateText = '';
      DateTime lastConnection = DateTime.fromMillisecondsSinceEpoch(device['lastConnection'] ?? 0);
      if(device['currentActivity']['state'] == 'none') stateText = device['lastConnection'] == 0 ? "currentActivity.state.neverConnected" : "currentActivity.state.connected".tr(namedArgs: {'since': getRelativeTime(context.locale.toString(), lastConnection, 'ago')});
      if(device['currentActivity']['state'] == 'connecting') stateText = "currentActivity.state.connecting".tr();
      if(device['currentActivity']['state'] == 'connected') stateText = "currentActivity.state.connected".tr(namedArgs: {'since': getRelativeTime(context.locale.toString(), startTime, 'since')});

      devicesItems.add(
        PopupMenuItem(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          mouseCursor: SystemMouseCursors.click,
          onTap: () async { // change selected device
            Haptic().light();

            try {
              await globals.bridge!.dispose();
            } catch (e) {
              logarte.log("Error while disposing bridge: $e");
            }

            globals.currentDevice = device;
            globals.box.write('selectedDeviceId', device['id']);
            if(context.mounted){
              initializedBridge = true;
              globals.initBridge(context);
            }
            globals.refreshStates(['main', 'settings', 'home']);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(device['id'] == globals.currentDevice['id'] ? LucideIcons.circleCheck : LucideIcons.circle, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 260
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device['name'] ?? "general.unknownData".tr(), style: TextStyle(color: Colors.grey[900], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$stateText • ${device['stats'].containsKey('totalDistanceKm') ? humanReadableDistance(globals.currentDevice['stats']['totalDistanceKm'] ?? 0, fromUnit: 'km') : "general.unknownData".tr()}', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
      );
    }

    Haptic().light();
    await showMenu<dynamic>(
      context: context,
      position: position,
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      popUpAnimationStyle: AnimationStyle(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInExpo,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      menuPadding: EdgeInsets.symmetric(vertical: 10),
      items: [
        ...devicesItems,

        PopupMenuDivider(),

        PopupMenuItem(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            Haptic().light();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.plus, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('devicesPicker.add.label'.tr(), style: TextStyle(color: Colors.grey[900], fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),

        PopupMenuItem(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          onTap: () {
            _deviceNameController.text = '';

            actionsDialog(
              context,
              title: 'devicesPicker.rename.dialogTitle'.tr(),
              content: 'devicesPicker.rename.dialogContent'.tr(namedArgs: {'bluetoothName': globals.currentDevice['bluetoothName']}),
              haptic: 'light',
              actionsPadding: const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 10),
              actions: [
                TextField(
                  controller: _deviceNameController,
                  decoration: InputDecoration(
                    border: UnderlineInputBorder(),
                    hintText: globals.currentDevice['bluetoothName'] ?? globals.currentDevice['name'] ?? "Nom de l'appareil",
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
                        late String finalName;
                        if(_deviceNameController.text.trim().isEmpty){
                          finalName = globals.currentDevice['bluetoothName'] ?? globals.currentDevice['name'] ?? "";
                        } else {
                          finalName = _deviceNameController.text;
                        }
                        globals.currentDevice['name'] = finalName;
                        globals.devices[globals.devices.indexWhere((element) => element['id'] == globals.currentDevice['id'])]['name'] = finalName;
                        globals.box.write('devices', globals.devices);
                        Navigator.of(context).pop();
                        globals.refreshStates(['main', 'settings', 'home']);
                        Haptic().success();
                      },
                    ),
                  ],
                ),
              ]
            );
          },
          mouseCursor: SystemMouseCursors.click,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.pencil, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('devicesPicker.rename.label'.tr(), style: TextStyle(color: Colors.grey[900], fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),

        PopupMenuItem(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            actionsDialog(
              context,
              title: 'devicesPicker.delete.dialogTitle'.tr(),
              content: 'devicesPicker.delete.dialogContent'.tr(namedArgs: {'name': globals.currentDevice['name']}),
              haptic: 'warning',
              actions: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
                  child: Text('general.cancel'.tr()),
                  onPressed: () {
                    Haptic().light();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red[500]),
                  child: Text('general.confirm'.tr()),
                  onPressed: () async {
                    try {
                      await globals.bridge!.dispose();
                    } catch (e) {
                      logarte.log("Error while disposing bridge: $e");
                    }

                    globals.devices.removeWhere((element) => element['id'] == globals.currentDevice['id']);
                    globals.box.write('devices', globals.devices);

                    Haptic().success();
                    if(globals.devices.isNotEmpty){
                      globals.currentDevice = globals.devices.first;
                      globals.box.write('selectedDeviceId', globals.currentDevice['id']);
                      if(context.mounted){
                        initializedBridge = true;
                        globals.initBridge(context);
                      }
                    } else {
                      globals.currentDevice = {};
                      globals.box.remove('selectedDeviceId');
                      if(context.mounted) Phoenix.rebirth(context);
                      return;
                    }

                    globals.refreshStates(['main', 'settings', 'home']);
                    if(context.mounted) Navigator.of(context).pop();
                  },
                ),
              ]
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.trash2, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('devicesPicker.delete.label'.tr(), style: TextStyle(color: Colors.grey[900], fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ],
    );
    Haptic().click();
  }

  @override
  void initState() {
    super.initState();

    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'refreshStates' && event['value'].contains('home')){
        logarte.log('Home: refreshing states');
        if (mounted) setState(() {});
      } else if(event['type'] == 'locationchange'){
        logarte.log('Home: location change received ; lat = ${event['data']['latitude']}, lng = ${event['data']['longitude']}');
        _mapWidgetKey.currentState?.updateGeocodedPosition(
          event['data']['latitude'], 
          event['data']['longitude']
        );
      } else if (event['type'] == 'databridge' && event['subtype'] == 'light') {
        ledTurnedOn = event['data'] as bool;

        // if(event['data'] == true) {
        //   ledAnimating = true;
        //   if(_ledTimer != null) _ledTimer!.cancel();
        //   _ledTimer = Timer(Duration(milliseconds: 400), () {
        //     ledAnimating = false;
        //     if(mounted) setState(() {});
        //   });
        // } else {
        //   ledAnimating = false;
        // }

        if(mounted) setState(() {});
      } else if (event['type'] == 'databridge' && event['subtype'] == 'locked') {
        isLocked = event['data'] as bool;
        if(mounted) setState(() {});
      } else if (event['type'] == 'databridge' && event['subtype'] == 'state' && event['data'] == 'none') {
        logarte.log('Home: disconnected from device');
        if(mounted) setState(() {});
        refreshAdvancedStats();
        redefinePositionWarn();
      } else if (event['type'] == 'databridge' && event['subtype'] == 'state' && event['data'] == 'connected') {
        startTime = DateTime.fromMillisecondsSinceEpoch(globals.currentDevice['currentActivity']['startTime'] ?? 0);
        if(mounted) setState(() {});
        refreshAdvancedStats();
        redefinePositionWarn();
      } else if (event['type'] == 'databridge' && event['subtype'] == 'state') {
        if(mounted) setState(() {});
        redefinePositionWarn();
      } else if (event['type'] == 'databridge' && event['subtype'] == 'distance') {
        if(mounted) setState(() {});
      }
    });

    _everyDemiMinuteTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      startTime = DateTime.fromMillisecondsSinceEpoch(globals.currentDevice['currentActivity']['startTime'] ?? 0);
      if(mounted) setState(() {});
    });
    _everyQuarterMinuteTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      if(globals.settings['useAdvancedStats'] == true && globals.currentDevice.containsKey('currentActivity') && globals.currentDevice['currentActivity']['state'] == 'connected'){
        int speedkmh = globals.currentDevice['currentActivity']['speedKmh'] ?? 0;
        if(speedkmh > 3){ // 4 km/h or +
          (globals.currentDevice['stats']['datas']['lastSpeedsKmh'] ?? []).add(speedkmh);
          if(globals.currentDevice['stats']['datas']['lastSpeedsKmh'].length > 720) globals.currentDevice['stats']['datas']['lastSpeedsKmh'].removeAt(0);
        }
      }
    });

    globals.musicPlayerHelper.init();

    getAppVersion().then((value) {
      if(!mounted) return;

      String currentVersion = globals.box.read('appVersion') ?? '0.0.0';
      if(currentVersion == value['version']) return;

      showChangelogModal(context);
      globals.box.write('appVersion', value['version']);
      globals.box.write('appBuild', value['buildNumber']);
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _everyDemiMinuteTimer.cancel();
    _everyQuarterMinuteTimer.cancel();
    _deviceNameController.dispose();
    globals.musicPlayerHelper.dispose();
    super.dispose();
  }

  Widget _buildMusicWidget() {
    return AspectRatio(
      aspectRatio: 1/1,
      child: GestureDetector(
        onTap: () async {
          Haptic().light();
          await showMaterialModalBottomSheet(
            duration: const Duration(milliseconds: 300),
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
            context: context,
            builder: (context) {
              return MusicPlayerScreen();
            },
          );
          Haptic().light();
        },
        onDoubleTap: () {
          Haptic().light();
          Haptic().light();
          globals.musicPlayerHelper.control('skipNext');
        },
        onLongPress: () {
          Haptic().heavy();
          globals.musicPlayerHelper.control('skipPrevious');
        },
        child: Container(
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
                Center( // visible when no cover artwork is available
                  child: Icon(LucideIcons.music, size: 32, color: Colors.grey[500]),
                ),

                ArtworkWidget(),

                // Gradient under the text but over the cover to make the text more readable
                globals.musicPlayerHelper.currentDetails['title'] == 'N/A' || globals.musicPlayerHelper.currentDetails['artist'] == 'N/A' || globals.musicPlayerHelper.currentDetails['title'] == null || globals.musicPlayerHelper.currentDetails['artist'] == null
                  ? SizedBox()
                  : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        stops: [0.4, 1]
                      ),
                    ),
                  ),

                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.1),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () {
                                Haptic().light();
                                if(globals.musicPlayerHelper.currentDetails['state'] == 'playing'){
                                  globals.musicPlayerHelper.control('pause');
                                } else {
                                  globals.musicPlayerHelper.control('play');
                                }
                              },
                              icon: Icon(
                                globals.musicPlayerHelper.currentDetails['state'] == 'playing' ? LucideIcons.pause : LucideIcons.play,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    globals.musicPlayerHelper.currentDetails['title'] == 'N/A' || globals.musicPlayerHelper.currentDetails['artist'] == 'N/A' || globals.musicPlayerHelper.currentDetails['title'] == null || globals.musicPlayerHelper.currentDetails['artist'] == null
                      ? SizedBox()
                      : Container(
                        constraints: BoxConstraints(minWidth: double.infinity),
                        child: Padding(
                          padding: EdgeInsets.only(top: 4, left: 12, right: 12, bottom: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${globals.musicPlayerHelper.currentDetails['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Sora', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                              Text('${globals.musicPlayerHelper.currentDetails['artist']}', maxLines: 1, overflow: TextOverflow.clip, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Sora', color: Colors.grey[200], fontWeight: FontWeight.w500, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              ]
            )
          ),
        )
      ),
    );
  }

  Widget _buildSheet({ ScrollController? scrollController }) {
    final paddingHeight = kToolbarHeight + MediaQuery.of(context).padding.top + MediaQuery.of(context).padding.bottom;
    double additionalPaddingTop = 18;

    return AnimatedContainer(
      constraints: globals.isLandscape ? BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - paddingHeight - additionalPaddingTop - (Platform.isIOS ? 11 : 0),
      ) : null,
      margin: globals.isLandscape ? EdgeInsets.only(top: additionalPaddingTop, right: 12, left: 12) : null,
      duration: Duration(milliseconds: 200),
      curve: Curves.bounceInOut,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: BorderRadius.only(
          topLeft: globals.isLandscape ? Radius.circular(25) : Radius.circular(12),
          topRight: globals.isLandscape ? Radius.circular(25) : Radius.circular(12),
          bottomLeft: globals.isLandscape ? Radius.circular(25) : Radius.circular(0),
          bottomRight: globals.isLandscape ? Radius.circular(25) : Radius.circular(0),
        ),
        boxShadow: globals.isLandscape ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        physics: ClampingScrollPhysics(),
        slivers: [
          // "Grab"
          SliverToBoxAdapter(
            child: globals.isLandscape ? SizedBox(height: 4) : Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                height: 3,
                width: 112,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
              ),
            ),
          ),

          // Sheet content
          SliverList(
            delegate: SliverChildListDelegate(
              [
                // Slide to Lock/Unlock
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 22),
                  child: ActionSlider.standard(
                    onTap: (controller, state, pos) {
                      Haptic().light();
                    },
                    stateChangeCallback: (oldState, state, controller){
                      // Haptic feedback when user drags the slider
                      if(state.slidingStatus == SlidingStatus.dragged) Haptic().click();
                    },
                    sliderBehavior: SliderBehavior.stretch,
                    reverseSlideAnimationCurve: Curves.easeInToLinear,
                    style: SliderStyle(
                      toggleColor: Colors.white,
                      backgroundColor: Theme.of(context).cardTheme.color
                    ),
                    icon: Icon(isLocked ? LucideIcons.lockOpen : LucideIcons.lock, color: isLocked ? Colors.deepOrangeAccent : Theme.of(context).colorScheme.primary),
                    direction: !isLocked ? TextDirection.ltr : TextDirection.rtl,
                    child: Text(isLocked ? 'controls.unlock'.tr() : 'controls.lock'.tr(), style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
                    action: (controller) async {
                      controller.loading(expanded: true);
                      Haptic().click();
                      await Future.delayed(Duration(milliseconds: 250)); // Should always be more than 200ms (250ms is good), else we can see the the icon transitionning before being remplaced by the loading spinner
                      Haptic().click();

                      await globals.bridge.setLock(!isLocked);

                      controller.success(expanded: true);
                      Haptic().click();
                      await Future.delayed(Duration(milliseconds: 800));
                      Haptic().light();
                      controller.reset();
                    },
                  ),
                ),

                !globals.isLandscape ? SizedBox() : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  child: BatteryIndicator()
                ),

                // Row 2/1 with 2 cards
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.speed'.tr(),
                            contentType: "widget",
                            height: 76,
                            content: Center(
                              child: SpeedModeSelector()
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.led'.tr(),
                            contentType: "widget",
                            height: 75,
                            // animation: ledAnimating ? "ledShadow" : "",
                            content: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Platform.isIOS ? CupertinoSwitch(
                                value: ledTurnedOn,
                                onChanged: (value) {
                                  Haptic().light();
                                  globals.bridge.turnLight(value);
                                },
                              )
                              : Switch(
                                activeTrackColor: Theme.of(context).colorScheme.primary,
                                value: ledTurnedOn,
                                onChanged: (value) {
                                  Haptic().light();
                                  globals.bridge.turnLight(value);
                                }
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Widgets
                globals.settings['enableDashboardWidgets'] != true ? SizedBox() : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: _buildMusicWidget()
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: EsciveMapWidget(key: _mapWidgetKey)
                        ),
                      ),
                    ],
                  ),
                ),

                // Texts statistics
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.stats.tripDistanceKm.title'.tr(),
                            content: globals.currentDevice.containsKey('stats') ? humanReadableDistance(globals.currentDevice['stats']['tripDistanceKm'] ?? 0, fromUnit: 'km') : '0 m',
                            hint: 'controls.stats.tripDistanceKm.hint'.tr()
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.stats.totalDistanceKm.title'.tr(),
                            content: globals.currentDevice.containsKey('stats') ? humanReadableDistance(globals.currentDevice['stats']['totalDistanceKm'] ?? 0, fromUnit: 'km') : '0 m',
                            hint: 'controls.stats.totalDistanceKm.hint'.tr()
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                globals.settings['useAdvancedStats'] == true ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.stats.todayDistanceKm.title'.tr(),
                            content: globals.currentDevice.containsKey('stats') ? humanReadableDistance(globals.currentDevice['stats']['todayDistanceKm'] ?? 0, fromUnit: 'km') : '0 m',
                            hint: 'controls.stats.todayDistanceKm.hint'.tr(),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.stats.weekDistanceKm.title'.tr(),
                            content: globals.currentDevice.containsKey('stats') ? humanReadableDistance(globals.currentDevice['stats']['weekDistanceKm'] ?? 0, fromUnit: 'km') : '0 m',
                            hint: 'controls.stats.weekDistanceKm.hint'.tr(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ) : const SizedBox(),
                globals.settings['useAdvancedStats'] == true ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.stats.averageSpeedKmh.title'.tr(),
                            content: "${globals.currentDevice.containsKey('stats') ? humanReadableDistance(globals.currentDevice['stats']['averageSpeedKmh'] ?? 0, fromUnit: 'km', decimalPlaces: 0) : '0 m'}/h",
                            hint: 'controls.stats.averageSpeedKmh.hint'.tr(),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: buildBasicCard(
                            context,
                            title: 'controls.stats.totalActivityTimeSecs.title'.tr(),
                            content: globals.currentDevice.containsKey('stats') ? humanReadableTime(globals.currentDevice['stats']['totalActivityTimeSecs'] ?? 0) : '0 min',
                            hint: 'controls.stats.totalActivityTimeSecs.hint'.tr(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ) : const SizedBox(),

                SizedBox(height: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar({ emptyContent = true }) {
    late Color deviceStatusColor;
    late IconData deviceStatusIcon;
    late String deviceStatusText;

    Map device = globals.currentDevice;
    DateTime startTime = DateTime.fromMillisecondsSinceEpoch(device['currentActivity']['startTime'] ?? 0);

    if(device['currentActivity']['state'] == 'none'){
      deviceStatusColor = Colors.red[400]!;
      deviceStatusIcon = LucideIcons.circleSlash600;
      deviceStatusText = "currentActivity.state.none".tr();
    } else if(device['currentActivity']['state'] == 'connecting'){
      deviceStatusColor = Colors.grey;
      deviceStatusIcon = LucideIcons.circleDashed600;
      deviceStatusText = "currentActivity.state.connecting".tr();
    } else if(device['currentActivity']['state'] == 'connected'){
      deviceStatusColor = Colors.green;
      deviceStatusIcon = Icons.circle;
      deviceStatusText = "currentActivity.state.connected".tr(namedArgs: {'since': getRelativeTime(context.locale.toString(), startTime, 'since')});
    }

    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark
      ),
      toolbarHeight: emptyContent ? 0 : null,
      actionsPadding: emptyContent ? null : EdgeInsets.only(right: 9, top: 6),
      title: emptyContent ? null : Padding(
        padding: EdgeInsets.only(left: 4, top: 6),
        child: GestureDetector(
          onTapDown: (TapDownDetails details) {
            if(globals.isLandscape){
              final RenderBox renderBox = deviceNameWidget.currentContext?.findRenderObject() as RenderBox;
              final Offset topLeft = renderBox.localToGlobal(Offset.zero);
              final flutter_rendering.Size widgetSize = renderBox.size;
              final Offset widgetPosition = Offset(topLeft.dx + widgetSize.width, topLeft.dy);

              showContextMenu(context, widgetPosition);
            } else {
              showContextMenu(context, Offset(0, 0));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                key: deviceNameWidget,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 1),
                  Expanded(
                    child: Text(
                      device['name'],
                      style: TextStyle(fontWeight: FontWeight.bold, overflow: TextOverflow.clip)
                    )
                  ),
                  // SizedBox(width: 2),
                  // Padding(
                  //   padding: EdgeInsets.only(top: 4),
                  //   child: Icon(Symbols.keyboard_arrow_down, size: 24, weight: 700),
                  // ),
                ],
              ),
              SizedBox(height: 1),
              Row(
                children: [
                  Icon(deviceStatusIcon, color: deviceStatusColor, size: 18),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(deviceStatusText, style: TextStyle(color: deviceStatusColor, fontSize: 18, fontWeight: FontWeight.w600))
                  ),
                ],
              ),
            ],
          ),
        )
      ),
      actions: emptyContent ? [] : [
        IconButton(
          icon: Icon(LucideIcons.settings, size: 30),
          onLongPress: () {
            Haptic().light();
            logarte.attach(context: context, visible: true);
          },
          onPressed: () {
            Haptic().light();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if(!initializedBridge){
      initializedBridge = true;
      logarte.log("Home: Trying to initialize bridge...");
      globals.initBridge(context);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFB7C0E2),
            Color(0xFFB3BAD9),
          ],
          stops: [0.0, 0.80, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Top app bar only on portrait mode
        appBar: globals.isLandscape ? _buildAppBar(emptyContent: true) : _buildAppBar(emptyContent: false),

        // App content
        body: SafeArea(
          bottom: globals.isLandscape,
          child: globals.isLandscape
          ? Row( // in landscape
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.only(left: 4, right: 4, top: Platform.isIOS ? 12 : 4, bottom: 4),
                  child: Center(
                    child: Speedometer()
                  ),
                ),
              ),

              Expanded(
                flex: 1,
                child: ListView(
                  physics: ClampingScrollPhysics(),
                  children: [
                    Platform.isIOS ? SizedBox(height: 10) : SizedBox(),
                    _buildAppBar(emptyContent: false), // app bar, but not in the top
                    _buildSheet()
                  ]
                )
              ),
            ]
          ) : Stack( // in portrait mode
            children: [
              // Main content (outside of sheet)
              Container(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    SizedBox(height: 4),
                    Speedometer(),
                    SizedBox(height: 20),
                    BatteryIndicator()
                  ],
                ),
              ),

              // Sheet
              DraggableScrollableSheet(
                initialChildSize: 0.36, // initial height
                minChildSize: 0.36, // min height
                maxChildSize: 0.975, // max height
                snap: true,
                snapSizes: [0.36, 0.975],
                snapAnimationDuration: Duration(milliseconds: 200),
                builder: (BuildContext context, scrollController) {
                  return _buildSheet(scrollController: scrollController);
                },
              ),
            ],
          ),
        )
      ),
    );
  }
}