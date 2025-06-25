import 'package:escive/widgets/banner_message.dart';
import 'package:escive/pages/test_speedometer.dart';
import 'package:escive/utils/actions_dialog.dart';
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/widgets/settings_tile.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

JsonEncoder jsonEncoder = JsonEncoder.withIndent('  ');

class LogarteCustomTab extends StatefulWidget {
  const LogarteCustomTab({super.key});

  @override
  State<LogarteCustomTab> createState() => _LogarteCustomTabState();
}

class _LogarteCustomTabState extends State<LogarteCustomTab> {
  final GetStorage box = GetStorage();

  void showDetails({ String title = 'Details', dynamic content, String? additional }) {
    String finalContent;
    try {
      finalContent = content.runtimeType == String ? content : jsonEncoder.convert(content);
    } catch(e) {
      finalContent = '${content.toString()} (failed to stringify)';
    }

    // if(additional != null) {
    //   finalContent = "$finalContent\n\n$additional";
    // }

    Clipboard.setData(ClipboardData(text: finalContent));
    actionsDialog(
      context,
      title: title,
      content: finalContent,
      haptic: "light"
    );
  }

  String exportPrefsToJson() {
    var keys = box.getKeys();
    var values = box.getValues();
    keys = keys.toList();
    values = values.toList();

    Map<String, dynamic> settings = {};
    for (var key in keys) {
      int index = keys.indexOf(key);
      settings[key] = values[index];
    }

    try {
      return jsonEncoder.convert(settings);
    } catch(e) {
      return "${settings.toString()} (Failed to stringify preferences)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 18.0),
      physics: ClampingScrollPhysics(),
      children: [
        bannerMessage(
          context,
          materialColor: Colors.red,
          content: Text(
            "You will usually need to restart the app after changing a setting for it to take effect.\n\nTo reduce issues, the global configuration in use isn’t always updated after a change.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
        ),
        SizedBox(height: 12),

        Row(
          spacing: 6,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  showDetails(title: "Saved settings", content: box.read("settings"));
                },
                child: const Text("Show settings"),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  box.remove("settings");
                  showSnackBar(context, "Settings have been erased", icon: "success");
                },
                child: const Text("Erase settings"),
              ),
            ),
          ],
        ),

        Row(
          spacing: 6,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  showDetails(title: "All preferences", content: exportPrefsToJson());
                },
                child: const Text("Show preferences"),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  box.erase();
                  showSnackBar(context, "All of preferences have been erased", icon: "success");
                },
                child: const Text("Erase all preferences"),
              ),
            ),
          ],
        ),

        Row(
          spacing: 6,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  showDetails(title: "Current device", content: globals.currentDevice);
                },
                child: const Text("Show current device"),
              ),
            ),

            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  showSnackBar(context, "Deleting \"${globals.currentDevice['id']}\" (${globals.devices.length} devices total)...");

                  globals.devices.removeWhere((element) => element['id'] == globals.currentDevice['id']);
                  box.write('devices', globals.devices);

                  if(globals.devices.isNotEmpty){
                    globals.currentDevice = globals.devices.first;
                    box.write('selectedDeviceId', globals.currentDevice['id']);
                  } else {
                    globals.currentDevice = {};
                    box.remove('selectedDeviceId');
                  }

                  showSnackBar(context, "The device has been deleted (${globals.devices.length} devices remaining)", icon: "success");
                },
                child: const Text("Delete current device"),
              ),
            ),
          ],
        ),

        Row(
          spacing: 6,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  String stringified = globals.devices.map((device) {
                    String deviceProperties;
                    try {
                      deviceProperties = jsonEncoder.convert(device);
                    } catch(e) {
                      deviceProperties = "${device.toString()} (failed to stringify)";
                    }
                    return "${device['name']} (${device['id']}):\n\n```\n$deviceProperties\n```";
                }).join("\n\n");
                  showDetails(title: 'All devices', content: stringified);
                },
                child: const Text("Show all devices"),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  box.remove("devices");
                  box.remove("selectedDeviceId");
                  showSnackBar(context, "All devices have been deleted", icon: "success");
                },
                child: const Text("Delete all devices"),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),
        Divider(),
        SizedBox(height: 12),

        Row(
          spacing: 6,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TestSpeedometer()),
                  );
                },
                child: const Text("Speedometer debugging"),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),
        Divider(),
        SizedBox(height: 12),

        Row(
          spacing: 6,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => globals.initBridge(context),
                child: const Text("Force init bridge"),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: () => globals.bridge!.dispose(),
                child: const Text("Force dispose bridge"),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),
        Divider(),
        SizedBox(height: 12),

        SettingsTile.toggle(
          context: context,
          title: "Disable auto bluetooth reconnect",
          subtitle: "Bridge will avoid to retry connecting when a Bluetooth connection is lost",
          value: globals.settings['disableAutoBluetoothReconnection'] ?? false,
          onChanged: (bool? value) {
            globals.setSettings('disableAutoBluetoothReconnection', value);
            globals.refreshWakelock();
            setState(() {}); // setSettings doesn't auto refresh on this page
          },
        ),
        SettingsTile.toggle(
          context: context,
          title: "Show track points on map",
          subtitle: "Up to 60 points will be shown on the map when displaying a segment from the positions history",
          value: globals.settings['showDebugTrackPoints'] ?? false,
          onChanged: (bool? value) {
            globals.setSettings('showDebugTrackPoints', value);
            setState(() {}); // setSettings doesn't auto refresh on this page
          },
        ),
      ],
    );
  }
}