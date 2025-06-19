import 'package:escive/main.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/widgets/warning_light.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

Future<dynamic> checkLocationPermission() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return "geolocator.serviceDisabled".tr();

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return "geolocator.permissions.denied".tr();
  }

  if (permission == LocationPermission.deniedForever) return "geolocator.permissions.deniedForever".tr();

  return true;
}

Future<Position> getCurrentPosition() async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      )
    );
  } catch (e) {
    rethrow;
  }
}

class PositionEmitter {
  bool currentlyEmittingPositionRealTime = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final List<double> _speedHistory = [];
  Timer? _stopTimer;

  static const int _historySize = 4;
  static const double _noiseThreshold = 2.0;
  static const double _precisionThreshold = 25.0;

  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );

  double _filterSpeed(double currentSpeed, double accuracy) {
    if (accuracy > _precisionThreshold) return _speedHistory.isNotEmpty ? _speedHistory.last : 0.0;

    _speedHistory.add(currentSpeed);
    if (_speedHistory.length > _historySize) _speedHistory.removeAt(0);

    if (_speedHistory.length < 2) return currentSpeed;

    double avgSpeed = _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;
    if (avgSpeed < _noiseThreshold) return 0.0; // avoid noise

    return avgSpeed;
  }

  void scheduleStop({ Duration delay = const Duration(minutes: 1) }) {
    if(_stopTimer != null) return; // avoid duplicates (if timer is already running, we don't want to schedule a new one)
    if(currentlyEmittingPositionRealTime == false) return; // avoid stopping if already stopped

    _stopTimer = Timer(delay, () {
      logarte.log('PositionEmitter: Scheduled stop reached');
      emitCurrentPositionRealTime(null, action: 'stop');
    });
    logarte.log('PositionEmitter: Stop is scheduled in ${delay.inSeconds} seconds');
  }

  void cancelScheduledStop() {
    if (_stopTimer != null) {
      _stopTimer!.cancel();
      _stopTimer = null;
      logarte.log('PositionEmitter: Canceled scheduled stop');
    }
  }

  void emitCurrentPositionRealTime(BuildContext? context, { String action = 'stop' }) async {
    redefinePositionWarn();

    if (action == 'start' && currentlyEmittingPositionRealTime == true) {
      return logarte.log('PositionEmitter: We\'ve already started emitting position in real time');
    }

    if (action == 'stop' || _positionStreamSubscription != null) {
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
      _speedHistory.clear();
      cancelScheduledStop();
      logarte.log('PositionEmitter: Stopped emitting position in real time');
      currentlyEmittingPositionRealTime = false;
      redefinePositionWarn();
      if (action == 'stop') return;
    }

    if(globals.settings['usePosition'] == 'never') {
      logarte.log('PositionEmitter: emitting position is disabled because user disabled data precision using position');
      currentlyEmittingPositionRealTime = false;
      return;
    }
    if(globals.settings['usePosition'] == 'auto' && globals.userDeviceBatteryLow) {
      logarte.log('PositionEmitter: emitting position is disabled because user device battery is low');
      currentlyEmittingPositionRealTime = false;
      return;
    }

    if (globals.settings['useSelfEstimatedSpeed'] != true) {
      logarte.log('PositionEmitter: emitting position to determine real time speed is disabled by user');
      currentlyEmittingPositionRealTime = false;
      return;
    }

    var locationPermission = await checkLocationPermission();
    if (locationPermission != true) {
      if (context != null && context.mounted) showSnackBar(context, locationPermission.toString());
      currentlyEmittingPositionRealTime = false;
      return;
    }

    try {
      await getCurrentPosition();
    } catch (e) {
      if (context != null && context.mounted) showSnackBar(context, "geolocator.cannotGetPosition".tr(namedArgs: {'error': e.toString()}));
      currentlyEmittingPositionRealTime = false;
      return;
    }

    logarte.log('PositionEmitter: Starting to use position to calculate real time speed');

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        double rawSpeedKmh = (position.speed.clamp(0.0, double.infinity)) * 3.6;
        double filteredSpeedKmh = _filterSpeed(rawSpeedKmh, position.accuracy);

        globals.socket.add({
          'type': 'databridge',
          'subtype': 'speed',
          'data': {
            'speedKmh': filteredSpeedKmh.round(),
            'source': 'gps',
            'precision': '±${position.accuracy.toStringAsFixed(1)}m'
          }
        });
        logarte.log('PositionEmitter: Speed is $filteredSpeedKmh km/h');
        logarte.log('PositionEmitter: Precision is ±${position.accuracy.toStringAsFixed(1)}m');
      },
      onError: (error) {
        logarte.log('PositionEmitter: Error from stream: $error');
        emitCurrentPositionRealTime(null, action: 'stop');
      },
    );

    currentlyEmittingPositionRealTime = true;
    redefinePositionWarn();
  }

  void dispose() {
    cancelScheduledStop();
    _positionStreamSubscription?.cancel();
  }
}
