import 'package:escive/main.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/send_kustom_variable.dart';

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

late Timer _randomDataTimer;
late Timer _saveInBoxTimer;

class DebugBridge {
  final Map<String, Timer> _setReadyStateTimers = {};

  void init(BuildContext context){
    logarte.log("Debug bridge: initializing...");

    sendKustomVariable(variableName: 'id', variableValue: (globals.currentDevice['id'] ?? 'unknown').toString());
    sendKustomVariable(variableName: 'name', variableValue: (globals.currentDevice['name'] ?? "general.defaultName".tr()).toString());
    sendKustomVariable(variableName: 'bluetoothName', variableValue: (globals.currentDevice['bluetoothName'] ?? "general.defaultName".tr()).toString());
    sendKustomVariable(variableName: 'protocol', variableValue: (globals.currentDevice['protocol'] ?? "unknown").toString());

    globals.socket.add({
      'type': 'databridge',
      'subtype': 'state',
      'data': 'connecting'
    });
    globals.currentDevice['currentActivity']['state'] = 'connecting';
    sendKustomVariable(variableName: 'state', variableValue: 'connecting');

    globals.currentDevice['currentActivity']['startTime'] = DateTime.now().millisecondsSinceEpoch;
    globals.currentDevice['lastConnection'] = globals.currentDevice['currentActivity']['startTime'];

    _randomDataTimer = Timer.periodic(Duration(seconds: 10), (timer) { // random data every 10 seconds
      globals.currentDevice['currentActivity']['battery'] = Random().nextInt(99) + 1;
      globals.socket.add({
        'type': 'databridge',
        'subtype': 'battery',
        'data': globals.currentDevice['currentActivity']['battery']
      });
      sendKustomVariable(variableName: 'battery', variableValue: globals.currentDevice['currentActivity']['battery'].toString());

      switch(globals.currentDevice['currentActivity']['speedMode']){
        case 0: // 1-10 km/h
          globals.currentDevice['currentActivity']['speedKmh'] = Random().nextInt(10) + 1;
          break;
        case 1: // 10-20 km/h
          globals.currentDevice['currentActivity']['speedKmh'] = Random().nextInt(10) + 10;
          break;
        case 2: // 20-30 km/h
          globals.currentDevice['currentActivity']['speedKmh'] = Random().nextInt(10) + 20;
          break;
        case 3: // 30-40 km/h
          globals.currentDevice['currentActivity']['speedKmh'] = Random().nextInt(10) + 30;
          break;
      }

      globals.socket.add({
        'type': 'databridge',
        'subtype': 'speed',
        'data': {
          'speedKmh': globals.currentDevice['currentActivity']['speedKmh'],
          'source': 'bridge'
        }
      });
      sendKustomVariable(variableName: 'speedKmh', variableValue: globals.currentDevice['currentActivity']['speedKmh'].toString());
    });

    _saveInBoxTimer = Timer.periodic(Duration(minutes: 1), (timer) => globals.saveInBox());

    globals.socket.add({
      'type': 'databridge',
      'subtype': 'state',
      'data': 'connected'
    });
    globals.currentDevice['currentActivity']['state'] = 'connected';
    setWarningLight('bridgeDisconnected', false);
    sendKustomVariable(variableName: 'state', variableValue: 'connected');
    logarte.log("Debug bridge: initialized");

    _setReadyState('speed');
    _setReadyState('lock');
    _setReadyState('light');
  }

  void _setReadyState(String state) {
    if(globals.bridgeReadyStates[state] == true) return;
    if(_setReadyStateTimers[state] != null && _setReadyStateTimers[state]!.isActive) return;

    _setReadyStateTimers[state] = Timer(Duration(milliseconds: 200), () {
      globals.bridgeReadyStates[state] = true;
    });
  }

  Future<bool> dispose() async {
    logarte.log("Debug bridge: disposing...");
    _randomDataTimer.cancel();
    _saveInBoxTimer.cancel();
    globals.saveInBox();

    if (_setReadyStateTimers.isNotEmpty) {
      _setReadyStateTimers.forEach((key, timer) => timer.cancel());
      _setReadyStateTimers.clear();
    }

    globals.resetCurrentActivityData();

    logarte.log("Debug bridge: disposed");
    return true;
  }

  Future<void> setSpeedMode(int speed) async {
    globals.socket.add({
      'type': 'databridge',
      'subtype': 'speedMode',
      'data': speed
    });
    globals.currentDevice['currentActivity']['speedMode'] = speed;
    sendKustomVariable(variableName: 'speedMode', variableValue: speed.toString());
  }

  Future<void> setLock(bool state) async {
    globals.socket.add({
      'type': 'databridge',
      'subtype': 'locked',
      'data': state
    });
    globals.currentDevice['currentActivity']['locked'] = state;
    sendKustomVariable(variableName: 'locked', variableValue: state.toString());
  }

  Future<void> turnLight(bool state) async {
    globals.socket.add({
      'type': 'databridge',
      'subtype': 'light',
      'data': state
    });
    globals.currentDevice['currentActivity']['light'] = state;
    sendKustomVariable(variableName: 'light', variableValue: state.toString());
  }

  Future<void> setWarningLight(String name, bool state) async {
    globals.socket.add({
      'type': 'databridge',
      'subtype': 'warningLight',
      'data': {
        'name': name,
        'value': state
      }
    });
  }
}