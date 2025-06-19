import 'package:escive/main.dart';
import 'package:escive/utils/actions_dialog.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

Future<void> addSavedDevice(BuildContext context, { String protocol = 'debug', String? name, String? bluetoothAddress, String? serviceUuid, String? writeCharacteristicUuid, String? readCharacteristicUuid }) async {
  try { // disconnect current device if any
    await globals.bridge!.dispose();
  } catch (e) {
    logarte.log("Error while disposing bridge: $e");
  }

  await globals.refreshDevices();

  // Avoid multiple devices with the same name
  while(name != null && globals.devices.any((element) => element['name'] == name)){
    dynamic lastDigitInName = int.parse(name[name.length - 1]);
    if(lastDigitInName == int){
      lastDigitInName++;
      name = name.substring(0, name.length - 1) + lastDigitInName.toString();
    } else {
      name = '$name 1';
    }
  }

  Map newDevice = globals.generateDeviceMap();
  newDevice['protocol'] = protocol;
  newDevice['name'] = name ?? 'Debugging n°${globals.devices.length + 1}';
  newDevice['bluetoothName'] = name ?? 'Debugging n°${globals.devices.length + 1}';
  newDevice['bluetoothAddress'] = bluetoothAddress ?? '';
  newDevice['serviceUuid'] = serviceUuid ?? '';
  newDevice['writeCharacteristicUuid'] = writeCharacteristicUuid ?? '';
  newDevice['readCharacteristicUuid'] = readCharacteristicUuid ?? '';
  if(protocol == 'debug'){
    newDevice['stats']['tripDistanceKm'] = Random().nextInt(20);
    newDevice['stats']['totalDistanceKm'] = Random().nextInt(170) + 80;
    newDevice['stats']['todayDistanceKm'] = newDevice['stats']['tripDistanceKm'] + Random().nextInt(10);
    newDevice['stats']['weekDistanceKm'] = newDevice['stats']['todayDistanceKm'] * Random().nextInt(5);
    newDevice['stats']['averageSpeedKmh'] = Random().nextInt(35) + 10;
    newDevice['stats']['totalActivityTimeSecs'] = Random().nextInt(20000) + 15000;
  }

  globals.devices.add(newDevice);
  globals.currentDevice = newDevice;
  globals.box.write('devices', globals.devices);
  globals.box.write('selectedDeviceId', newDevice['id']);

  Haptic().success();
  await globals.refreshDevices();
  if(context.mounted) showSnackBar(context, "addDevice.addSuccess".tr(), icon: "success");
  globals.refreshStates(['main', 'home', 'addDevice', 'onboarding' 'settings']);
  if(context.mounted && Navigator.of(context).canPop()){
    Navigator.of(context).pop();
  } else if(context.mounted) {
    Phoenix.rebirth(context);
  }

  if(context.mounted) globals.initBridge(context);
}

Future<void> askDevicePassword(BuildContext context, { String? hint, int? maxLength, bool digitsOnly = false }) async {
  final TextEditingController passwordController = TextEditingController();
  final Completer<void> completer = Completer<void>();

  actionsDialog(
    context,
    canBeIgnored: false, // prevent user from closing dialog
    title: 'bridges.password.dialogTitle'.tr(),
    content: 'bridges.password.dialogContent'.tr(),
    haptic: 'light',
    actionsPadding: const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 10),
    actions: [
      TextField(
        controller: passwordController,
        maxLength: maxLength,
        keyboardType: digitsOnly ? TextInputType.number : TextInputType.visiblePassword,
        obscureText: false,
        decoration: InputDecoration(
          border: UnderlineInputBorder(),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400])
        ),
      ),

      SizedBox(height: 12),

      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.blue[500]),
            child: Text('general.confirm'.tr()),
            onPressed: () {
              String? password;
              if(passwordController.text.trim().isEmpty){ // if there isn't any password
                if(hint != null){ // use hint
                  password = hint;
                } else { // user NEED to enter a password
                  return Haptic().error();
                }
              } else {
                password = passwordController.text;
              }

              globals.currentDevice['passwordProtection'] = password;
              globals.saveInBox();
              Navigator.of(context).pop();
              globals.refreshStates(['home']);
              Haptic().light();

              completer.complete();
              Timer(Duration(milliseconds: 900), () {
                passwordController.dispose(); // to avoid disposing it while the dialog is still open (while fading out)
              });
            },
          ),
        ],
      ),
    ]
  );

  return completer.future;
}