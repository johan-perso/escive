import 'dart:async';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:universal_io/io.dart';

class OrientationManager {
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;
  String _accepted = 'all';

  List<DeviceOrientation> getAccepted(String accepted) {
    if(accepted == 'landscape') {
      return [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    } else if(accepted == 'landscapeLeft') {
      return Platform.isIOS ? [DeviceOrientation.landscapeRight] : [DeviceOrientation.landscapeLeft];
    } else if(accepted == 'landscapeRight') {
      return Platform.isIOS ? [DeviceOrientation.landscapeLeft] : [DeviceOrientation.landscapeRight];
    } else {
      return [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    }
  }

  void forceAutoRotate({ String accepted = 'all' }) {
    if(accepted == 'auto') accepted = 'all';
    _accepted = accepted;

    if (_orientationSubscription != null) _orientationSubscription!.cancel();
    _orientationSubscription = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen((orientation) {
          updateOrientation(orientation);
        }
    );

    SystemChrome.setPreferredOrientations(getAccepted(_accepted));
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
        if (_accepted == 'all') allowedOrientations = [DeviceOrientation.portraitUp];
        break;
      case NativeDeviceOrientation.portraitDown:
        if (_accepted == 'all') allowedOrientations = [DeviceOrientation.portraitDown];
        break;
      case NativeDeviceOrientation.landscapeLeft:
        if(_accepted == 'all' || _accepted == 'landscapeLeft') allowedOrientations = Platform.isIOS ? [DeviceOrientation.landscapeRight] : [DeviceOrientation.landscapeLeft]; // ios is just, reversed??
        break;
      case NativeDeviceOrientation.landscapeRight:
        if(_accepted == 'all' || _accepted == 'landscapeRight') allowedOrientations = Platform.isIOS ? [DeviceOrientation.landscapeLeft] : [DeviceOrientation.landscapeRight];
        break;
      default:
        allowedOrientations = getAccepted(_accepted);
    }

    if (allowedOrientations.isNotEmpty) SystemChrome.setPreferredOrientations(allowedOrientations);
  }
}