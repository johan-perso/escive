import 'dart:async';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class OrientationManager {
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;
  bool _onlyLandscape = false;

  void forceAutoRotate({ bool onlyLandscape = false }) {
    _onlyLandscape = onlyLandscape;

    if (_orientationSubscription != null) _orientationSubscription!.cancel();
    _orientationSubscription = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen((orientation) {
          updateOrientation(orientation);
        }
    );

    if(onlyLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void stopForcingAutoRotate() {
    _orientationSubscription?.cancel();
    _orientationSubscription = null;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void updateOrientation(NativeDeviceOrientation orientation) {
    List<DeviceOrientation> allowedOrientations = [];

    switch (orientation) {
      case NativeDeviceOrientation.portraitUp:
        if (!_onlyLandscape) allowedOrientations = [DeviceOrientation.portraitUp];
        break;
      case NativeDeviceOrientation.portraitDown:
        if (!_onlyLandscape) allowedOrientations = [DeviceOrientation.portraitDown];
        break;
      case NativeDeviceOrientation.landscapeLeft:
        allowedOrientations = [DeviceOrientation.landscapeLeft];
        break;
      case NativeDeviceOrientation.landscapeRight:
        allowedOrientations = [DeviceOrientation.landscapeRight];
        break;
      default:
        if (_onlyLandscape) {
          allowedOrientations = [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
        } else {
          allowedOrientations = [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
        }
    }

    if (allowedOrientations.isNotEmpty) SystemChrome.setPreferredOrientations(allowedOrientations);
  }
}