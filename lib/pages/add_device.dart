import 'package:escive/main.dart';
import 'package:escive/utils/check_bluetooth_permission.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/utils/add_saved_device.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/bridges/iscooter.dart';
import 'package:escive/widgets/banner_message.dart';
import 'package:escive/widgets/classic_app_bar.dart';
import 'package:escive/widgets/settings_tile.dart';
import 'package:escive/widgets/web_viewport_wrapper.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

List protocols = [
  {
    "id": "iscooter",
    "title": "protocols.iscooter.title".tr(),
    "subtitle": "protocols.iscooter.subtitle".tr(),
  },
  // {
  //   "id": "debug",
  //   "title": "Debug",
  //   "subtitle": "Random data, used when adding a virtual/fake device, without any connection to Bluetooth device",
  // },
];

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSubscription;
  bool disableActions = false;
  String scanState = 'none';
  String scanContentText = '';
  List scannedDevices = [];
  List scanTimeouts = [];
  late AnimationController _iconAnimationController;
  late Animation<double> _iconAnimation;

  void startScan() async {
    logarte.log("startScan() called");
    if (!mounted) return;
    setState(() {
      scannedDevices = [];
    });

    bool gotBluetoothPermission = await checkBluetoothPermission(context);
    if(!gotBluetoothPermission) return;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        logarte.log("Trying to turn on Bluetooth...");
        await FlutterBluePlus.turnOn();
      } catch (e) {
        logarte.log("Failed to automatically enable Bluetooth: $e");
      }
    }

    if(globals.currentDevice.containsKey('currentActivity') && globals.currentDevice['currentActivity']['state'] == 'connecting'){
      logarte.log("Waiting for current device to drop connection before starting scan...");
      await globals.bridge!.dispose();
      logarte.log("Current device dropped connection, starting scan...");
    }

    int devicesCount = 0;

    logarte.log("Creating scan results listener...");
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if(scannedDevices.any((element) => element['address'] == r.device.remoteId.toString())) continue;
        if(r.device.platformName == '') continue;
        logarte.log("Found device: name: ${r.device.platformName} ; id: ${r.device.remoteId}");

        scannedDevices.add({
          'name': r.device.platformName,
          'address': r.device.remoteId.toString(),
          'rssi': r.rssi,
        });
      }

      if(devicesCount != scannedDevices.length){
        Haptic().click();
        devicesCount = scannedDevices.length;
      }
      if (!mounted) return;
      setState(() {});
    });

    if (!mounted) return;
    setState(() {
      scanState = 'scanning';
      _iconAnimationController.repeat();
    });

    logarte.log("Starting scan...");
    late Timer timeout;
    try {
      FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        webOptionalServices: globals.webOptionalServices,
      );
      timeout = Timer(const Duration(seconds: 30), () {
        if(scanState == 'scanning'){
          logarte.log("30 seconds after starting scan: still scanning, stopping now.");
          stopScan();
        } else {
          logarte.log("30 seconds after starting scan: already stopped.");
        }
      });
      scanTimeouts.add(timeout);
      logarte.log("Scan started.");
    } catch (e) {
      logarte.log("Error occurred while starting scan: $e");
      if(mounted) showSnackBar(context, "addDevice.errors.whileSearching".tr(namedArgs: {'error': e.toString()}), icon: "error");
      if(timeout.isActive) timeout.cancel();
      stopScan();
    }
  }

  Future<void> stopScan() async {
    logarte.log("Stopping scan...");

    for (var element in scanTimeouts) {
      element.cancel();
    }

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      logarte.log("Error occurred while stopping scan: $e");
      if(mounted) showSnackBar(context, "addDevice.errors.stopScan".tr(namedArgs: {'error': e.toString()}));
    }

    if (!mounted) return;
    setState(() {
      scanState = 'stopped';
      _iconAnimationController.stop();
    });

    logarte.log("Scan stopped.");
  }

  Future<void> bluetoothDeviceDisconnect(device) async {
    try {
      await device.disconnect();
    } catch (e) {
      logarte.log("Error occurred while disconnecting Bluetooth device: $e");
    }
  }

  void updateScanContentText(content){
    if (!mounted) return;
    setState(() {
      scanContentText = content;
    });
  }

  Widget _buildCompatibilityWarn(){
    List compatibilityList = [];
    compatibilityList.addAll(IscooterBridge().supportedDevicesList);

    return bannerMessage(
      context,
      materialColor: Colors.red,
      content: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: "addDevice.warns.compatibility".tr(),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700]),
          children: compatibilityList.map((e) => TextSpan(
            text: e,
            style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)),
          )).toList(),
        )
      ),
    );
  }

  List<Widget> _buildDevicesList(ColorScheme colorScheme){
    if (scannedDevices.isNotEmpty){
      return [
        Row(
          children: [
            Icon(LucideIcons.bluetoothSearching, color: colorScheme.primary),
            SizedBox(width: 8),
            Text(
              'addDevice.devicesFounds'.plural(scannedDevices.length, namedArgs: {'count': scannedDevices.length.toString()}),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 16),

        ...scannedDevices.asMap().entries.map((entry) {
          final device = entry.value;

          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SettingsTile.action(
              context: context,
              title: device['name'] != '' ? device['name'] : 'addDevice.unknownDevice'.tr(),
              subtitle: '${'addDevice.address'.tr()}: ${device['address']}\n${'addDevice.rssiSignal'.tr()}: ${device['rssi']} dBm',
              onChanged: (value) async {
                if(disableActions) return;

                updateScanContentText("addDevice.states.connecting".tr(namedArgs: {'name': device['name'] != '' ? device['name'] : 'addDevice.unknownDevice'.tr()}));
                Haptic().light();

                try {
                  if (scanState == 'scanning') await stopScan();

                  final BluetoothDevice bluetoothDevice = await FlutterBluePlus.scanResults
                    .firstWhere((results) => results.any((r) => r.device.remoteId.toString() == device['address']))
                    .then((results) => results.firstWhere((r) => r.device.remoteId.toString() == device['address']).device);

                  // Connect to the device
                  disableActions = true;
                  logarte.log("Connecting to device: ${bluetoothDevice.platformName}");
                  await bluetoothDevice.connect(timeout: const Duration(seconds: 15));
                  logarte.log("Connected to device: ${bluetoothDevice.platformName}");
                  updateScanContentText("addDevice.states.connected".tr(namedArgs: {'name': bluetoothDevice.platformName}));

                  // Discover services
                  updateScanContentText("addDevice.states.completing".tr());
                  logarte.log("Discovering services...");
                  List<BluetoothService> services = await bluetoothDevice.discoverServices();
                  logarte.log("${services.length} services discovered");

                  // Auto detect the mains services and characteristics
                  logarte.log("Automatic search for main services and characteristics...");

                  BluetoothService? targetService;
                  BluetoothCharacteristic? writeCharacteristic;
                  BluetoothCharacteristic? readCharacteristic;

                  String? detectedServiceUuid;
                  String? detectedWriteCharacteristicUuid;
                  String? detectedReadCharacteristicUuid;

                  // Search interestings services
                  Map<BluetoothService, List<BluetoothCharacteristic>> potentialServices = {};
                  for (BluetoothService service in services) {
                    logarte.log("Service discovered: ${service.uuid}");

                    List<BluetoothCharacteristic> writableCharacteristics = [];
                    List<BluetoothCharacteristic> readableCharacteristics = [];
                    List<BluetoothCharacteristic> notifiableCharacteristics = [];

                    for (BluetoothCharacteristic characteristic in service.characteristics) {
                      logarte.log("  - Characteristic: ${characteristic.uuid}");
                      logarte.log("    Properties: read=${characteristic.properties.read}, write=${characteristic.properties.write}, notify=${characteristic.properties.notify}");

                      if(characteristic.properties.write) writableCharacteristics.add(characteristic);
                      if(characteristic.properties.read) readableCharacteristics.add(characteristic);
                      if(characteristic.properties.notify) notifiableCharacteristics.add(characteristic);
                    }

                    // If this service has almost one characteristic of reading and writing, we consider it as a potential service
                    if(writableCharacteristics.isNotEmpty && (readableCharacteristics.isNotEmpty || notifiableCharacteristics.isNotEmpty)) {
                      logarte.log("Potential service found: ${service.uuid}");
                      potentialServices[service] = service.characteristics;
                    }
                  }

                  // We try to select the most favorable service (the one with the most characteristics)
                  if (potentialServices.isNotEmpty) {
                    // Sort the services by the number of characteristics (in descending order)
                    final sortedServices = potentialServices.entries.toList()
                      ..sort((a, b) => b.value.length.compareTo(a.value.length));

                    // Select the first service (the one with the most number of characteristics)
                    targetService = sortedServices.first.key;
                    detectedServiceUuid = targetService.uuid.toString();
                    logarte.log("Main service selected: ${targetService.uuid}");

                    // Search for characteristics in this service
                    for (BluetoothCharacteristic characteristic in targetService.characteristics) {
                      // Priorise characteristic that has read and write
                      if (characteristic.properties.write && characteristic.properties.read && detectedWriteCharacteristicUuid == null) {
                        writeCharacteristic = characteristic;
                        detectedWriteCharacteristicUuid = characteristic.uuid.toString();
                        logarte.log("Write characteristic selected: ${characteristic.uuid}");
                      }

                      // Notification characteristic
                      if (characteristic.properties.notify && !characteristic.properties.write && !characteristic.properties.read) {
                        readCharacteristic = characteristic;
                        detectedReadCharacteristicUuid = characteristic.uuid.toString();
                        logarte.log("Read/notify characteristic selected: ${characteristic.uuid}");
                      }
                    }

                    // If we didn't found a characteristic with read and write, we search for a write only one
                    if (writeCharacteristic == null) {
                      for (BluetoothCharacteristic characteristic in targetService.characteristics) {
                        if (characteristic.properties.write) {
                          writeCharacteristic = characteristic;
                          detectedWriteCharacteristicUuid = characteristic.uuid.toString();
                          logarte.log("Alternative write characteristic selected: ${characteristic.uuid}");
                          break;
                        }
                      }
                    }

                    if (readCharacteristic == null) {
                      // Priorise characteristic with notificaion
                      for (BluetoothCharacteristic characteristic in targetService.characteristics) {
                        if (characteristic.properties.notify) {
                          readCharacteristic = characteristic;
                          detectedReadCharacteristicUuid = characteristic.uuid.toString();
                          logarte.log("Alternative notify characteristic selected: ${characteristic.uuid}");
                          break;
                        }
                      }

                      // If still not found, we search for a read only one
                      if (readCharacteristic == null) {
                        for (BluetoothCharacteristic characteristic in targetService.characteristics) {
                          if (characteristic.properties.read) {
                            readCharacteristic = characteristic;
                            detectedReadCharacteristicUuid = characteristic.uuid.toString();
                            logarte.log("Alternative read characteristic selected: ${characteristic.uuid}");
                            break;
                          }
                        }
                      }
                    }
                  } else { // No potential service found
                    logarte.log("No potential service found with read and write characteristics");
                  }

                  // Final check than we have found a service with characteristics of reading and writing
                  if (targetService != null) {
                    logarte.log("Main service found: $detectedServiceUuid");

                    if (writeCharacteristic != null && readCharacteristic != null) {
                      final message = "UUIDs detected:\nService: $detectedServiceUuid\nWrite: $detectedWriteCharacteristicUuid\nRead: $detectedReadCharacteristicUuid";
                      logarte.log(message);

                      // We will test the communication with the device
                      bool valueReadSuccessful = false;
                      try {
                        if (readCharacteristic.properties.notify) { // enable notifications if possible
                          await readCharacteristic.setNotifyValue(true);
                          logarte.log("Notifications enabled successfully");
                          valueReadSuccessful = true;

                          await readCharacteristic.setNotifyValue(false); // disable notifications, test concluded
                        } else { // only try to read as a test
                          final value = await readCharacteristic.read();
                          logarte.log("Value read: $value");
                          valueReadSuccessful = true;
                        }
                      } catch (e) {
                        logarte.log("Error while testing the communication (reading characteristic): $e");
                      }

                      if(valueReadSuccessful){
                        await bluetoothDeviceDisconnect(bluetoothDevice); // disconnect now because we will reconnect with the protocol we need to use
                        logarte.log("Disconnected device after checking UUIDs with success");

                        if(!mounted) return;
                        showSelectModal(
                          context: context,
                          title: 'addDevice.selectProtocol'.tr(),
                          values: protocols,
                          onChanged: (value) async { // some devices may need a password but the bridge will ask for it and add it to the preferences
                            await addSavedDevice(
                              context,
                              name: device['name'] != '' ? device['name'] : 'addDevice.unknownDevice'.tr(),
                              protocol: protocols[value]['id'],
                              bluetoothAddress: device['address'],
                              serviceUuid: detectedServiceUuid,
                              writeCharacteristicUuid: detectedWriteCharacteristicUuid!,
                              readCharacteristicUuid: detectedReadCharacteristicUuid!,
                            );
                            if(scanState == 'scanning') await stopScan();
                          }
                        );
                      } else {
                        disableActions = false;
                        if(mounted) showSnackBar(context, "addDevice.errors.communicationTestFailed".tr(), icon: "error");
                        Haptic().error();
                        updateScanContentText('');
                        await bluetoothDeviceDisconnect(bluetoothDevice);
                      }
                    } else {
                      disableActions = false;
                      if(mounted) showSnackBar(context, "addDevice.errors.noCharacteristic".tr(), icon: "error");
                      Haptic().error();
                      updateScanContentText('');
                      await bluetoothDeviceDisconnect(bluetoothDevice);
                    }
                  } else {
                    disableActions = false;
                    if(mounted) showSnackBar(context, "addDevice.errors.noMainService".tr(), icon: "error");
                    Haptic().error();
                    updateScanContentText('');
                    await bluetoothDeviceDisconnect(bluetoothDevice);
                  }
                } catch (e) {
                  disableActions = false;
                  logarte.log("Error while connecting: $e");
                  if(mounted) showSnackBar(context, "addDevice.errors.connectionError".tr(namedArgs: {'error': e.toString()}), icon: "error");
                  Haptic().error();
                  updateScanContentText('');

                  // Try to disconnect the device as we don't need it anymore
                  final BluetoothDevice bluetoothDevice = await FlutterBluePlus.scanResults
                    .firstWhere((results) => results.any((r) => r.device.remoteId.toString() == device['address']))
                    .then((results) => results.firstWhere((r) => r.device.remoteId.toString() == device['address']).device);

                  await bluetoothDeviceDisconnect(bluetoothDevice);
                }
              },
            ),
          );
        })
      ];
    } else if (scanState == 'stopped'){
      return [
        bannerMessage(
          context,
          materialColor: Colors.amber,
          content: Column(
            children: [
              Icon(LucideIcons.info, color: Colors.amber[700], size: 32),
              SizedBox(height: 12),
              Text(
                'addDevice.devicesFounds.zero'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'addDevice.noDevicesFoundsHint'.tr(),
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    } else if (scanState == 'none'){
      return [
        bannerMessage(
          context,
          materialColor: Colors.blue,
          content: Column(
            children: [
              Icon(LucideIcons.bluetooth, color: Colors.blue[700], size: 32),
              SizedBox(height: 12),
              Text(
                'addDevice.states.readyBanner'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                "addDevice.clickToSearch".tr(),
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    } else {
      return [];
    }
  }

  Widget _buildScanContent({ ColorScheme? colorScheme, bool includeBackground = false, bool includeVerticalMargin = false, double parentWidth = 0 }) {
    return Container(
      margin: includeVerticalMargin ? EdgeInsets.symmetric(vertical: 10) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: includeBackground ? Colors.white : Colors.transparent,
        // borderRadius: globals.largeScreenW ? BorderRadius.all(Radius.circular(12)) : BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        boxShadow: includeBackground ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ] : null,
      ),
      // width: globals.largeScreenW ? 400 : double.infinity,
      alignment: Alignment.center,
      padding: includeBackground ? EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 32) : EdgeInsets.zero,
      // padding: EdgeInsets.only(left: 20, right: 20, top: globals.largeScreenW ? 18 : 20, bottom: globals.largeScreenW ? 18 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scanState == 'scanning') ...[  
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: _iconAnimation,
                  child: Icon(Icons.refresh, color: Colors.grey[700]),
                ),
                SizedBox(width: 8),
                Text(
                  "addDevice.states.scanning".tr(),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ] else ...[  
            Text(
              scanContentText != '' ? scanContentText : scanState == "stopped" ? "addDevice.states.stoppedState".tr() : scanState == "none" ? "addDevice.states.readyState".tr() : scanState,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.only(left: Platform.isIOS ? 4 : 0, right: Platform.isIOS ? 4 : 0, bottom: Platform.isIOS ? 4 : 0),
              child: FilledButton(
                onPressed: disableActions ? null : () async {
                  Haptic().light();

                  if(scanState == 'none' || scanState == 'stopped'){
                    startScan();
                  } else if(scanState == 'scanning') {
                    stopScan();
                  }
                },
                onLongPress: disableActions ? null : () async {
                  if(scanState != 'none' && scanState != 'stopped') return;
                  await stopScan();
                  if(mounted) await addSavedDevice(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: scanState == 'scanning' ? Colors.red[400] : colorScheme?.primary,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      scanState == "scanning" ? Icons.stop : Icons.search,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      scanState == "scanning" ? "addDevice.states.actions.stopScan${parentWidth > 290 ? "Long" : "Short"}".tr() : scanState == "stopped" ? "addDevice.states.actions.restartScan${parentWidth > 290 ? "Long" : "Short"}".tr() : scanState == "none" ? "addDevice.states.actions.startScan${parentWidth > 290 ? "Long" : "Short"}".tr() : scanState,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    globals.refreshSettings();

    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _iconAnimation = CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.easeInOut,
    );

    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'refreshStates' && event['value'].contains('addDevice')){
        logarte.log('addDevice page: refreshing states');
        if (mounted) setState(() {});
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _iconAnimationController.dispose();

    for (var timeout in scanTimeouts) {
      timeout.cancel();
    }
    scanTimeouts.clear();

    if (scanState == 'scanning') FlutterBluePlus.stopScan();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WebViewportWrapper(
      child: Scaffold(
        appBar: classicAppBar(context, 'addDevice.pageTitle'.tr(), showDebugButton: true),
        body: Container(
          decoration: BoxDecoration(
            gradient: globals.isLandscape ? null : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.grey[50]!],
            ),
          ),
          child: SafeArea(
            bottom: globals.isLandscape ? true : false,
            child: globals.isLandscape
              ? Row( // landscape
                children: [
                  Expanded(
                    flex: 65, // 65%
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      physics: ClampingScrollPhysics(),
                      children: [
                        ..._buildDevicesList(colorScheme)
                      ],
                    )
                  ),
                  Expanded(
                    flex: 35, // 35%
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        return ListView(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          physics: ClampingScrollPhysics(),
                          children : [
                            _buildScanContent(colorScheme: colorScheme, includeVerticalMargin: true, parentWidth: constraints.maxWidth),
                            const SizedBox(height: 24),
                            _buildCompatibilityWarn(),
                          ],
                        );
                      }
                    ),
                  ),
                ],
              ) : Column( // portrait
                children: [
                  // Main content of the page
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      physics: ClampingScrollPhysics(),
                      children: [
                        _buildCompatibilityWarn(),
                        const SizedBox(height: 24),
                        ..._buildDevicesList(colorScheme)
                      ],
                    ),
                  ),

                  // Scan state in the bottom
                  _buildScanContent(colorScheme: colorScheme, includeBackground: true, parentWidth: MediaQuery.of(context).size.width),
                ],
              ),
          ),
        )
      )
    );
  }
}