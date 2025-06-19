import 'package:escive/main.dart';
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'package:flutter/material.dart';

void redefineBatteryWarn() {
  if(globals.bridge == null) return;

  bool result = false;
  if(globals.userDeviceBatteryLow){
    logarte.log("lowBattery: User device has low battery, turning on warning light");
    result = true;
  } else if(globals.currentDevice.containsKey('currentActivity') && globals.currentDevice['currentActivity']['battery'] < 16){
    logarte.log("lowBattery: Vehicle has low battery, turning on warning light");
    result = true;
  } else {
    logarte.log("lowBattery: No battery warning are detected, turning off warning light");
  }

  globals.bridge.setWarningLight('lowBattery', result);
}

void redefinePositionWarn() {
  if(globals.bridge == null) return;

  bool result = true;
  if(globals.settings['usePosition'] == 'always'){
    logarte.log("positionPrecisionDisabled: Setting to use position for advanced precision is set on always enabled, turning off warning light");
    result = false;
  } else if(globals.settings['usePosition'] == 'auto' && !globals.userDeviceBatteryLow){
    logarte.log("positionPrecisionDisabled: Setting to use position for advanced precision is set on auto and user device isn't on low battery, turning off warning light");
    result = false;
  }

  if(globals.settings['useSelfEstimatedSpeed'] == true && globals.positionEmitter.currentlyEmittingPositionRealTime != true){
    logarte.log("positionPrecisionDisabled: Setting to use self estimated speed is turned on but position is not being emitted, turning on warning light");
    result = true;
  }
  if(globals.positionEmitter.currentlyEmittingPositionRealTime){
    logarte.log("positionPrecisionDisabled: Position is being emitted, turning off warning light");
    result = false;
  }

  globals.bridge.setWarningLight('positionPrecisionDisabled', result);
}

Widget warningLight(BuildContext context, { bool enabled = false, bool showInactivesWarnsLights = false, IconData? icon, double size = 24, Color? color, String hint = '' }) {
  return AnimatedOpacity(
    opacity: enabled ? 1 : showInactivesWarnsLights ? 0.2 : 0,
    duration: const Duration(milliseconds: 170),
    child: InkWell(
      onTap: () => showSnackBar(context, hint),
      child: Icon(icon, size: size, color: color)
    )
  );
}