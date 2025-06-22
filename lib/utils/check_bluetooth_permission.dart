import 'package:escive/main.dart';
import 'package:escive/utils/show_snackbar.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

Future<bool> checkBluetoothPermission(BuildContext context) async {
    logarte.log("checkBluetoothPermission() called");
    FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);

    if(Platform.isAndroid){
      var status = await Permission.bluetoothConnect.status;
      logarte.log("bluetoothConnect permission status (first try): $status");
      if (!status.isGranted) {
        status = await Permission.bluetoothConnect.request();
        logarte.log("bluetoothConnect permission status (second/last try): $status");
        if (!status.isGranted) {
          if(context.mounted) showSnackBar(context, "bluetoothPermission.denied".tr(), icon: "error");
          Timer(Duration(seconds: 3), () => openAppSettings());
          return false;
        }
      }
    }

    if(await FlutterBluePlus.isSupported == false){
      logarte.log("Bluetooth is not supported on this device");
      if(context.mounted) showSnackBar(context, "bluetoothPermission.unsupported".tr(), icon: "error");
      return false;
    }

    return true;
  }