library escive.globals;

import 'package:escive/main.dart';
import 'package:escive/bridges/debug.dart';
import 'package:escive/bridges/iscooter.dart';
import 'package:escive/pages/music_player.dart';
import 'package:escive/utils/geolocator.dart';
import 'package:escive/utils/send_kustom_variable.dart';
import 'package:escive/utils/system_rotations.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

MusicPlayerHelper musicPlayerHelper = MusicPlayerHelper();
OrientationManager orientationManager = OrientationManager();

String lastWeatherCheckDate = "";
String lastWeatherFetchDate = "";
Map lastWeatherData = {};

int userDeviceBatteryLevel = 100;
bool userDeviceBatteryLow = false;
PositionEmitter positionEmitter = PositionEmitter();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
double screenWidth = 0;
double screenHeight = 0;
bool largeScreenW = screenWidth > 700;
bool isLandscape = false;
bool appIsInForeground = true;

final box = GetStorage();
Map cache = {};
Uuid uuid = Uuid();
StreamController socket = StreamController.broadcast();

late Map<String, dynamic> settings;
late String selectedDeviceId;
late List devices;
Map currentDevice = {};

final List<Guid> webOptionalServices = [ // web browsers deny requests without this property
  Guid('6d581e70-15c6-11ec-82a8-0002a5d5c51b') // iScooter service
];

Map bridgeReadyStates = defaultReadyStates;
dynamic bridge;
void initBridge(BuildContext context) async {
  logarte.log("Initializing bridge (from globals)...");
  if(bridge != null){
    logarte.log("Was already connected to a bridge, disposing it...");
    await bridge.dispose();
  }

  if(currentDevice.isNotEmpty){
    logarte.log("Using protocol \"${currentDevice['protocol']}\" for device \"${currentDevice['name']}\" with id \"${currentDevice['id']}\"");

    if(currentDevice['protocol'] == 'debug'){
      bridge = DebugBridge();
    } else if(currentDevice['protocol'] == 'iscooter'){
      bridge = IscooterBridge();
    } else {
      return logarte.log("Unknown protocol \"${currentDevice['protocol']}\", failed to initialize bridge");
    }

    if(bridge != null && context.mounted) bridge.init(context);
  } else {
    logarte.log("Failed to initialize bridge: no device selected");
  }
}

Map get defaultSupportedProperties => {
  "battery": true,
  "speedModeLength": 4,
  "lock": true,
  "light": true
};
Map get defaultCurrentActivity => {
  "state": "none", // none (never connected or disconnected) ; connecting, connected
  "startTime": 0,
  "battery": 0,
  "speedKmh": 0,
  "speedMode": 0,
  "locked": false,
  "light": false,
};
Map get defaultStats => {
  "tripDistanceKm": 0,
  "totalDistanceKm": 0,
  "todayDistanceKm": 0,
  "weekDistanceKm": 0,
  "averageSpeedKmh": 0,
  "totalActivityTimeSecs": 0,
  "datas": {
    "totalDistanceKmAtMidnight": 0,
    "lastMidnightTime": null,
    "allDaysDistanceKm": {},
    "lastSpeedsKmh": [],
    "lastActivityTimeUpdate": null
  },
  "positionHistory": []
};
Map get defaultReadyStates => {
  "lock": false,
  "speed": false,
  "light": false,
};
Map generateDeviceMap(){
  return {
    "id": uuid.v4(),
    "name": "general.defaultName".tr(),
    "bluetoothName": "",
    "bluetoothAddress": "",
    "serviceUuid": "",
    "writeCharacteristicUuid": "",
    "readCharacteristicUuid": "",
    "lastConnection": 0,
    "protocol": "debug",
    "passwordProtection": null,
    "supportedProperties": defaultSupportedProperties,
    "currentActivity": defaultCurrentActivity,
    "stats": defaultStats
  };
}

void refreshStates(List pages){
  socket.add({ 'type': 'refreshStates', 'value': pages });
}

Future<void> refreshSettings() async {
  logarte.log("Refreshing settings...");
  settings = box.read('settings') ?? {};

  List defaultSettings = [
    { "key": "useAdvancedStats", "value": true, "type": bool },
    { "key": "usePosition", "value": 'never', "type": String },
    { "key": "useSelfEstimatedSpeed", "value": false, "type": bool },
    { "key": "showInactivesWarnsLights", "value": true, "type": bool },
    { "key": "maxRenderedSpeedKmh", "value": "25", "type": String },
    { "key": "keepScreenTurnedOn", "value": false, "type": bool },
    { "key": "forceScreenBrightnessMax", "value": false, "type": bool },
    { "key": "forceAutoRotation", "value": 'default', "type": String },
    { "key": "enableDashboardWidgets", "value": false, "type": bool },
    { "key": "enableWeatherCheck", "value": false, "type": bool },
    { "key": "disableAutoBluetoothReconnection", "value": false, "type": bool },
    { "key": "showDebugTrackPoints", "value": false, "type": bool },
    { "key": "customUiLanguage", "value": '', "type": String },
    { "key": "favoritesPlaces", "value": [], "type": List },
  ];

  for(var element in defaultSettings) {
    if(!settings.containsKey(element['key'])) {
      logarte.log("Settings ${element['key']} not found, setting to ${element['value']}");
      setSettings(element['key'], element['value']);
    } else {
      if(settings[element['key']].runtimeType != element['type']) {
        logarte.log("Settings ${element['key']} has wrong type, resetting to ${element['value']}");
        setSettings(element['key'], element['value']);
      }
    }
  }

  logarte.log("Refreshed settings: $settings");
}

Future<void> refreshDevices() async {
  logarte.log("Refreshing devices...");
  
  if(currentDevice.isNotEmpty && currentDevice['currentActivity']['state'] != 'none'){
    logarte.log("Can't refresh devices while a device is connected");
    return;
  }

  devices = box.read('devices') ?? [];
  devices = devices.map((device) => {
    ...device,
    'currentActivity': defaultCurrentActivity,
  }).toList();

  selectedDeviceId = box.read('selectedDeviceId') ?? '';
  if(devices.isNotEmpty) currentDevice = devices.firstWhere((element) => element['id'] == selectedDeviceId, orElse: () => generateDeviceMap());

  logarte.log("Refreshed devices: $devices");
}

void resetCurrentActivityData(){
  bridgeReadyStates = defaultReadyStates;
  currentDevice['stats']['tripDistanceKm'] = 0;

  socket.add({
    'type': 'databridge',
    'subtype': 'state',
    'data': 'none'
  });
  currentDevice['currentActivity']['state'] = 'none';
  sendKustomVariable(variableName: 'state', variableValue: 'none');

  socket.add({
    'type': 'databridge',
    'subtype': 'speedMode',
    'data': 0
  });
  currentDevice['currentActivity']['speedMode'] = 0;
  sendKustomVariable(variableName: 'speedMode', variableValue: '0');

  socket.add({
    'type': 'databridge',
    'subtype': 'locked',
    'data': false
  });
  currentDevice['currentActivity']['locked'] = false;
  sendKustomVariable(variableName: 'locked', variableValue: 'false');

  socket.add({
    'type': 'databridge',
    'subtype': 'light',
    'data': false
  });
  currentDevice['currentActivity']['light'] = false;
  sendKustomVariable(variableName: 'light', variableValue: 'false');

  socket.add({
    'type': 'databridge',
    'subtype': 'battery',
    'data': 0
  });
  currentDevice['currentActivity']['battery'] = 0;
  sendKustomVariable(variableName: 'battery', variableValue: '0');

  socket.add({
    'type': 'databridge',
    'subtype': 'speed',
    'data': {
      'speedKmh': 0,
      'source': 'bridge'
    }
  });
  currentDevice['currentActivity']['speedKmh'] = 0;
  sendKustomVariable(variableName: 'speedKmh', variableValue: '0');

  socket.add({
    'type': 'databridge',
    'subtype': 'warningLight',
    'data': {
      'name': 'bridgeDisconnected',
      'state': true
    }
  });
}

void setSettings(String key, dynamic value) {
  settings[key] = value;
  refreshStates(['main', 'home', 'settings', 'speedometer', 'maps']);
  logarte.log("Setting $key to $value");
  box.write('settings', settings);
}

void saveInBox(){
  if(devices.isEmpty || currentDevice.isEmpty || !currentDevice.containsKey('id')){
    logarte.log("Debug bridge: not saving in box because conditions aren't matched...");
    return;
  }

  int currentDeviceIndex = devices.indexWhere((element) => element['id'] == currentDevice['id']);
  if(currentDeviceIndex != -1) devices[currentDeviceIndex] = currentDevice;

  box.write('devices', devices);
}

void refreshWakelock() async {
  bool wakelockEnabled = await WakelockPlus.enabled;

  if(settings['keepScreenTurnedOn'] ?? false){
    if(!wakelockEnabled){
      await WakelockPlus.enable();
      logarte.log('Wakelock enabled');
    }
  } else {
    if(wakelockEnabled){
      await WakelockPlus.disable();
      logarte.log('Wakelock disabled');
    }
  }
}