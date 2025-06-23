import 'package:escive/main.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

late Timer _randomDataTimer;
late Timer _saveInBoxTimer;

class DebugBridge {
  void init(BuildContext context){
    logarte.log("Debug bridge: initializing...");

    globals.socket.add({
      'type': 'databridge',
      'subtype': 'state',
      'data': 'connecting'
    });
    globals.currentDevice['currentActivity']['state'] = 'connecting';

    globals.currentDevice['currentActivity']['startTime'] = DateTime.now().millisecondsSinceEpoch;
    globals.currentDevice['lastConnection'] = globals.currentDevice['currentActivity']['startTime'];

    _randomDataTimer = Timer.periodic(Duration(seconds: 10), (timer) { // random data every 10 seconds
      globals.currentDevice['currentActivity']['battery'] = Random().nextInt(99) + 1;
      globals.socket.add({
        'type': 'databridge',
        'subtype': 'battery',
        'data': globals.currentDevice['currentActivity']['battery']
      });

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
    });

    _saveInBoxTimer = Timer.periodic(Duration(minutes: 1), (timer) => globals.saveInBox());

    globals.socket.add({
      'type': 'databridge',
      'subtype': 'state',
      'data': 'connected'
    });
    globals.currentDevice['currentActivity']['state'] = 'connected';
    setWarningLight('bridgeDisconnected', false);
    logarte.log("Debug bridge: initialized");
  }

  Future<bool> dispose() async {
    logarte.log("Debug bridge: disposing...");
    _randomDataTimer.cancel();
    _saveInBoxTimer.cancel();
    globals.saveInBox();

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
  }

  Future<void> setLock(bool state) async {
    globals.socket.add({
      'type': 'databridge',
      'subtype': 'locked',
      'data': state
    });
    globals.currentDevice['currentActivity']['locked'] = state;
  }

  Future<void> turnLight(bool state) async {
    globals.socket.add({
      'type': 'databridge',
      'subtype': 'light',
      'data': state
    });
    globals.currentDevice['currentActivity']['light'] = state;
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