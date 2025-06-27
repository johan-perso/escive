import 'package:escive/main.dart';
import 'package:escive/utils/add_saved_device.dart';
import 'package:escive/utils/check_bluetooth_permission.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/show_snackbar.dart';

import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

Timer? _reconnectionTimer;
Timer? _searchDeviceTimer;
Timer? _saveInBoxTimer;

String? connectedDeviceAddress;
BluetoothDevice? connectedDevice;
StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

BluetoothCharacteristic? writeCharacteristic;
BluetoothCharacteristic? readCharacteristic;
Timer? _requestTimer;
StreamSubscription<List<int>>? _dataSubscription;

Completer<String>? pmCompleter;
Completer<String>? codeCompleter;
class IscooterEncryption { // mostly written by AI, i can't handle all ts honestly
  // Hardcoded encryptions keys
  final List<int> encryptionSBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b,
    0xfe, 0xd7, 0xab, 0x76, 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0,
    0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0, 0xb7, 0xfd, 0x93, 0x26,
    0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2,
    0xeb, 0x27, 0xb2, 0x75, 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0,
    0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, 0x53, 0xd1, 0x00, 0xed,
    0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f,
    0x50, 0x3c, 0x9f, 0xa8, 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5,
    0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2, 0xcd, 0x0c, 0x13, 0xec,
    0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14,
    0xde, 0x5e, 0x0b, 0xdb, 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c,
    0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, 0xe7, 0xc8, 0x37, 0x6d,
    0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f,
    0x4b, 0xbd, 0x8b, 0x8a, 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e,
    0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e, 0xe1, 0xf8, 0x98, 0x11,
    0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f,
    0xb0, 0x54, 0xbb, 0x16
  ];
  final String encryptionAesKey = "9883222CD5B257133F3AC675A7132B44";
  final String encryptionIvKey = "9E716E81E1A71CB524884953B2275BBD";

  final List<int> _bondingNonce = List<int>.filled(6, 0);
  final List<int> _bondingHash = List<int>.filled(4, 0);
  final List<int> _keyTmp = List<int>.filled(16, 0);

  String? encryptionStringOfValue(String hexString) {
    if (hexString.length < 12) return null;

    // Convert hex string to bytes for bonding_nonce
    for (int i = 0; i < 6; i++) {
      String hexByte = hexString.substring(i * 2, (i * 2) + 2);
      _bondingNonce[i] = int.parse(hexByte, radix: 16);
    }

    // Generate hash with custom algorithm
    _bondingHashGenerate();

    // Convert result to hex string
    String result = "";
    for (int i = 0; i < 4; i++) {
      String hexValue = _bondingHash[i].toRadixString(16);
      if (hexValue.length < 2) hexValue = "0$hexValue";
      result += hexValue;
    }

    return result;
  }

  void _bondingHashGenerate() {
    // Create a 32-character buffer for calculations
    List<int> buffer = List<int>.filled(32, 0);

    // Step 1: Copy the 6-byte nonce to 3 different locations in the buffer
    // Copy 1: positions 0-5
    for (int i = 0; i < 6; i++) {
      buffer[i] = _bondingNonce[i];
    }

    // Copy 2: positions 6-11
    for (int i = 0; i < 6; i++) {
      buffer[6 + i] = _bondingNonce[i];
    }

    // Copy 3: positions 12-15 (only 4 bytes)
    for (int i = 0; i < 4; i++) {
      buffer[12 + i] = _bondingNonce[i];
    }

    // Step 2: Shift the first 15 bytes to the right
    // Copy buffer[1] to buffer[15] to buffer[16] to buffer[30]
    for (int i = 1; i < 16; i++) {
      buffer[15 + i] = buffer[i];
    }

    // The last byte (position 31) takes the value of the first byte (position 0)
    buffer[31] = buffer[0];

    // Step 3: Generate temporary key
    _bondingKeyGenerate();

    // Step 4: Apply XOR transformations with key and IV
    List<int> ivBytes = _hexStringToBytes(encryptionIvKey);

    for (int i = 0; i < 16; i++) {
      int c2 = buffer[i];
      int keyByte = _keyTmp[i];
      int ivByte = ivBytes[i];

      // First transformation: buffer[i] = (c2 XOR keyTmp[i]) XOR iv[i]
      buffer[i] = (c2 ^ keyByte) ^ ivByte;

      // Second transformation: buffer[i+16] = (keyTmp[i] XOR buffer[i+16]) XOR iv[i]
      int i2 = i + 16;
      buffer[i2] = (keyByte ^ buffer[i2]) ^ ivByte;
    }

    // Step 5: Cascade propagation
    // First half (positions 1-15)
    for (int i = 1; i < 16; i++) {
      buffer[i] = buffer[i] ^ buffer[i - 1];
    }

    // Second half (positions 17-31)
    for (int i = 1; i < 16; i++) {
      int index = i + 16;
      buffer[index] = buffer[index] ^ buffer[index - 1];
    }

    // Step 6: Final calculation of 4-byte hash
    for (int i = 0; i < 4; i++) {
      // Complex combination of 8 different buffer positions
      int result = buffer[i + 0] ^ 
                  buffer[i + 4] ^ 
                  buffer[i + 8] ^ 
                  (buffer[i + 12] + buffer[i + 16]) ^ 
                  buffer[i + 20] ^ 
                  buffer[i + 24] ^ 
                  buffer[i + 28];

      // Mask to 8 bits and store in final hash
      _bondingHash[i] = result & 0xFF;
    }
  }

void _bondingKeyGenerate() {
    // Create temporary 4-byte buffer
    List<int> tempBuffer = List<int>.filled(4, 0);

    // Convert AES key from hex to bytes and copy to _keyTmp
    List<int> keyBytes = _hexStringToBytes(encryptionAesKey);
    for (int i = 0; i < 16; i++) {
      _keyTmp[i] = keyBytes[i];
    }

    // Apply S-Box on the 16 bytes of the key
    _subBytes(_keyTmp, 16);

    // Save the first 4 bytes
    for (int i = 0; i < 4; i++) {
      tempBuffer[i] = _keyTmp[i];
    }

    // Shift bytes 4-15 to positions 0-11
    for (int i = 0; i < 12; i++) {
      _keyTmp[i] = _keyTmp[i + 4];
    }

    // Copy temporary buffer to positions 12-15
    for (int i = 0; i < 4; i++) {
      _keyTmp[12 + i] = tempBuffer[i];
    }
  }

  void _subBytes(List<int> data, int length) {
    // Apply S-Box transformation on each byte
    for (int i = 0; i < length; i++) {
      data[i] = encryptionSBox[data[i] & 0xFF];
    }
  }

  List<int> _hexStringToBytes(String hexString) {
    // Convert hexadecimal string to list of bytes
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      String hexByte = hexString.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return bytes;
  }
}

class IscooterBridge {
  List supportedDevicesList = ['iScooter i10Max'];
  BuildContext? context;
  final Map<String, Timer> _setReadyStateTimers = {};

  String _encryptNonce(String hexNonce) {
    // Convert the hexadecimal nonce to a list of bytes
    List<int> nonceBytes = [];
    for (int i = 0; i < hexNonce.length; i += 2) {
      nonceBytes.add(int.parse(hexNonce.substring(i, i + 2), radix: 16));
    }

    // Use the IscooterEncryption class to encrypt the nonce into a hash (will be sent to the scooter)
    IscooterEncryption encryption = IscooterEncryption();
    String encryptedNonce = encryption.encryptionStringOfValue(hexNonce)!;

    return encryptedNonce;
  }

  String _generateRandomChallenge() {
    Random random = Random();
    String challenge = "";
    for (int i = 0; i < 6; i++) {
      challenge += (random.nextInt(256)).toString();
    }
    return challenge;
  }

  void init(BuildContext context) async {
    logarte.log("iScooter bridge: initializing...");
    this.context = context;

    globals.socket.add({
      'type': 'databridge',
      'subtype': 'state',
      'data': 'connecting'
    });
    globals.currentDevice['currentActivity']['state'] = 'connecting';

    globals.currentDevice['stats']['tripDistanceKm'] = 0; // should be done when disconnecting, but in case app was closed without proper dispose

    bool gotBluetoothPermission = await checkBluetoothPermission(context);
    if(!gotBluetoothPermission){
      logarte.log("iScooter bridge: failed to get bluetooth permission");
      dispose();
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        logarte.log("iScooter bridge: Trying to turn on Bluetooth...");
        await FlutterBluePlus.turnOn();
      } catch (e) {
        logarte.log("iScooter bridge: Failed to automatically enable Bluetooth: $e");
      }
    }

    await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first; // wait for bluetooth to be turned on and granted
    logarte.log("iScooter bridge: bluetooth is on");

    connectedDeviceAddress = globals.currentDevice['bluetoothAddress'].toString();
    if(context.mounted){
      await _connectToDevice(context);
    } else {
      logarte.log("iScooter bridge: context is not mounted, skipping device connection");
      return;
    }
  }

  Future<void> _connectToDevice(BuildContext context) async {
    String targetAddress = globals.currentDevice['bluetoothAddress'];
    logarte.log("iScooter bridge: searching for device with address: $targetAddress");

    String serviceUuid = globals.currentDevice['serviceUuid'];
    String writeCharacteristicUuid = globals.currentDevice['writeCharacteristicUuid'];
    String readCharacteristicUuid = globals.currentDevice['readCharacteristicUuid'];

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.remoteId.str == targetAddress) {
          logarte.log("iScooter bridge: found target device, connecting...");

          await FlutterBluePlus.stopScan();

          try {
            await result.device.connect(
              autoConnect: false, // tell system to avoid reconnecting when connection is lost
              timeout: Duration(seconds: 15),
              mtu: null
            );

            connectedDevice = result.device;

            if(_connectionSubscription != null) await _connectionSubscription?.cancel();
            _connectionSubscription = result.device.connectionState.listen((state) {
              if (state == BluetoothConnectionState.disconnected) { // when device is disconnected
                logarte.log("iScooter bridge: device got disconnected");
                _handleDisconnection(context.mounted ? context : null);
              }
            });

            logarte.log("iScooter bridge: device connected, discovering services...");
            List<BluetoothService> services = await result.device.discoverServices();
            logarte.log("iScooter bridge: ${services.length} services discovered");

            BluetoothService? targetService;
            for (BluetoothService service in services) {
              if (service.uuid.toString() == serviceUuid) {
                logarte.log("iScooter bridge: found target service");
                targetService = service;
                break;
              }
            }

            if (targetService != null) {
              // Search characteristics
              for (BluetoothCharacteristic characteristic in targetService.characteristics) {
                if (characteristic.uuid.toString() == writeCharacteristicUuid) {
                  writeCharacteristic = characteristic;
                  logarte.log("iScooter bridge: found write characteristic");
                }
                if (characteristic.uuid.toString() == readCharacteristicUuid) {
                  readCharacteristic = characteristic;
                  logarte.log("iScooter bridge: found read characteristic");

                  // Configure notifications
                  if (characteristic.properties.notify) {
                    try {
                      await characteristic.setNotifyValue(true);
                      _dataSubscription = characteristic.lastValueStream.listen((value) {
                        if (value.isNotEmpty) handleScooterData(value);
                      });
                      logarte.log("iScooter bridge: notifications enabled");
                    } catch (e) {
                      logarte.log("iScooter bridge: failed to enable notifications: $e");
                    }
                  }
                }
              }
            } else {
              logarte.log("iScooter bridge: target service not found");
              _handleDisconnection(context.mounted ? context : null);
              return;
            }

            // (Below contains the multiple-steps authentification process)
            await sendCommand(utf8.encode("+VER?").toList()); // response: +VER=JLSH10S10 // we don't really need it

            pmCompleter = Completer<String>();
            Future.delayed(Duration(seconds: 10), () {
              if (!pmCompleter!.isCompleted) pmCompleter!.completeError("Timeout");
            });
            sendCommand(utf8.encode("+PM?").toList()); // response: +PM>F49A5EAABE50 // no need to await because we wait for the completer response

            String? receivedNonce;
            try {
              receivedNonce = await pmCompleter!.future;
              logarte.log("iScooter bridge: PM response: $receivedNonce");
            } catch (e) {
              logarte.log("iScooter bridge: Error or timeout when waiting for the PM response: $e");
            }

            if (receivedNonce == null) {
              logarte.log("iScooter bridge: PM response is empty");
              _handleDisconnection(context.mounted ? context : null);
              return;
            }

            pmCompleter = Completer<String>();
            Future.delayed(Duration(seconds: 10), () {
              if (!pmCompleter!.isCompleted) pmCompleter!.completeError("Timeout");
            });
            String encryptedNonceResponse = _encryptNonce(receivedNonce);
            sendCommand(utf8.encode("+PM<$encryptedNonceResponse").toList()); // response: +PM>OK or +PM>NK

            String? checkNonceResponse;
            try {
              checkNonceResponse = await pmCompleter!.future;
              logarte.log("iScooter bridge: Double PM response: $checkNonceResponse");
            } catch (e) {
              logarte.log("iScooter bridge: Error or timeout when waiting for the double PM response: $e");
            }

            if (checkNonceResponse == null || !checkNonceResponse.contains("OK") || checkNonceResponse == "NK") {
              logarte.log("iScooter bridge: Double PM response is empty, invalid or incorrect");
              logarte.log("iScooter bridge: First PM response was \"$receivedNonce\" and was encrypted in été encrypted into \"$encryptedNonceResponse\" ; double PM response: \"$checkNonceResponse\"");
              _handleDisconnection(context.mounted ? context : null);
              return;
            }

            String challenge = _generateRandomChallenge();
            await sendCommand(utf8.encode("+PA<$challenge").toList()); // response: +PA>E9AA77C2 // the scooter allows us to check the challenge to confirm the connection, but we don't have to

            // If we doesn't have any password saved, we ask the user to enter it
            if(globals.currentDevice['passwordProtection'] == null || globals.currentDevice['passwordProtection'].isEmpty){
              if(context.mounted) await askDevicePassword(context, hint: '000000', maxLength: 6, digitsOnly: true); // hint is the default password in some iScooter devices
              if(globals.currentDevice['passwordProtection'] == null || globals.currentDevice['passwordProtection'].isEmpty){
                logarte.log("iScooter bridge: password is null even after trying to ask for it, disposing bridge");
                _handleDisconnection(context.mounted ? context : null);
                return;
              }
            }

            String scooterSecretCode = globals.currentDevice['passwordProtection'];
            codeCompleter = Completer<String>();
            Future.delayed(Duration(seconds: 10), () {
              if (!codeCompleter!.isCompleted) codeCompleter!.completeError("Timeout");
            });
            sendCommand(utf8.encode("CODE=$scooterSecretCode").toList());

            String? checkCodeResponse;
            try {
              checkCodeResponse = await codeCompleter!.future;
              logarte.log("iScooter bridge: response to auth code check: $checkCodeResponse");
            } catch (e) {
              logarte.log("iScooter bridge: Error or timeout when waiting for the auth code check: $e");
            }

            if (checkCodeResponse != "OK" || checkCodeResponse == "NG") {
              logarte.log("iScooter bridge: auth code check response is invalid or incorrect");
              logarte.log("iScooter bridge: The code \"$scooterSecretCode\" is invalid, response was: $checkCodeResponse");
              globals.currentDevice['passwordProtection'] = null;
              if(context.mounted) showSnackBar(context, "bridges.password.incorrect".tr());
              _handleDisconnection(context.mounted ? context : null);
              return;
            }

            // The official apps send those commands even if it seems useless
            await sendCommand(utf8.encode("GETDEVID").toList());
            await sendCommand(utf8.encode("+UNIT=?").toList());
            await sendCommand(utf8.encode("+MODE=?").toList());
            await sendCommand(utf8.encode("+HLGT=?").toList());
            await sendCommand(utf8.encode("+LOCK=?").toList());

            _setReadyState('speed');

            // We're in!
            globals.currentDevice['currentActivity']['startTime'] = DateTime.now().millisecondsSinceEpoch;
            globals.currentDevice['lastConnection'] = globals.currentDevice['currentActivity']['startTime'];

            _saveInBoxTimer = Timer.periodic(Duration(minutes: 1), (timer) => globals.saveInBox());

            globals.socket.add({
              'type': 'databridge',
              'subtype': 'state',
              'data': 'connected'
            });
            globals.currentDevice['currentActivity']['state'] = 'connected';
            setWarningLight('bridgeDisconnected', false);
            logarte.log("iScooter bridge: connected successfully");
          } catch (e) {
            logarte.log("iScooter bridge: connection failed: $e");
            _handleDisconnection(context.mounted ? context : null);
          }
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: 30),
      androidUsesFineLocation: false,
      webOptionalServices: globals.webOptionalServices,
    );

    _searchDeviceTimer = Timer(Duration(seconds: 35), () async {
      if (connectedDevice == null) {
        await _scanResultsSubscription?.cancel();
        logarte.log("iScooter bridge: device not found within timeout");
        _handleDisconnection(context.mounted ? context : null);
      }
    });
  }

  Future<void> sendCommand(List<int> data) async {
    if (writeCharacteristic == null) {
      logarte.log("iScooter bridge: write characteristic not found");
      return;
    }

    try {
      await writeCharacteristic!.write(data, withoutResponse: true);
    } catch (e) {
      logarte.log("iScooter bridge: error sending command: $e");
    }

    await Future.delayed(Duration(milliseconds: 110 + Random().nextInt(100)));
  }

  void handleScooterData(List<int> value) {
    if (value.isEmpty) return;

    // Indicate a text message data
    if (value[0] == 43 || value[0] == 67) {
      try {
        String decodedString = utf8.decode(value);
        logarte.log("iScooter bridge: handleScooterData: received data: $decodedString");

        if (pmCompleter != null && !pmCompleter!.isCompleted) {
          if (decodedString.startsWith("+PM>")) pmCompleter!.complete(decodedString.split(">")[1]);
          return;
        }

        if (codeCompleter != null && !codeCompleter!.isCompleted) {
          if (decodedString.startsWith("CODE_")) codeCompleter!.complete(decodedString.split("_")[1]);
          return;
        }
      } catch (e) {
        logarte.log("iScooter bridge: handleScooterData: failed to decode UTF8: $e");
      }
      return;
    }

    // if (value.length < 8){
    //   logarte.log("iScooter bridge: handleScooterData: packet received is too short, only ${value.length} bytes received instead of 8, skipping");
    //   return;
    // }

    if (value[0] == 170) {
      switch (value[1]) {
        case 3:
          if(value.length >= 9){
            logarte.log("iScooter bridge: handleScooterData: (determine lock state): bytes received: ${value.map((e) => e.toRadixString(10)).toList()}");

            // These packets seem to just break everything idc what they correspond to ; value[7] == 169 or 168 seems to be good.
            // I have NO CLUE on how this shit works, i guess i'm never touching this code again. 3 hours of debugging with Wireshark, Jadx, Perplexity + Claude.
            // PLEASE don't break over the time
            if(value[7] == 175 || value[7] == 174){
              logarte.log('iScooter bridge: handleScooterData: (determine lock state): this packet will NOT help us to determine lock state.');
              return;
            }

            bool isLocked = _determineLockStatus(value);
            logarte.log("iScooter bridge: handleScooterData: (determine lock state): scooter is ${isLocked ? "locked" : "unlocked"}");
            setLock(isLocked, emitToDevice: false);
          }
          break;
        case 161: // Status packets
          handleStatusPacket(value);
          break;
        case 162: // ODO/TRIP packets
          if(value.length < 10) return;

          int tripRaw = value[4] + (value[5] << 8);
          double trip = tripRaw / 10.0;

          int odoRaw = (value[6] << 16) + (value[7] << 8) + value[8];
          double odo = odoRaw / 2560.0;
          logarte.log("iScooter bridge: handleScooterData: (ODO/TRIP): trip: $trip km ; odo: $odo km");

          // Update globals data
          globals.currentDevice['stats']['tripDistanceKm'] = trip;
          globals.currentDevice['stats']['totalDistanceKm'] = odo;

          globals.socket.add({
            'type': 'databridge',
            'subtype': 'distance'
          });
          break;
      }
    }
  }

  // bool _determineLockStatus(List<int> packet) {
  //   if (packet.length < 6) {
  //     debugPrint("iScooter bridge: _determineLockStatus: packet too short");
  //     return false;
  //   }

  //   int pos3 = packet[3]; // relation between light state and lock
  //   int pos5 = packet[5]; // state of the led (0 = OFF ; 1 = ON)
  //   bool lightOn = pos5 == 1;

  //   if(pos3 == 4 && !lightOn){ // light off, unlocked
  //     return false;
  //   } else if(pos3 == 2 && lightOn){ // light on, unlocked
  //     return false;
  //   } else if(pos3 == 2 && !lightOn){ // light off, locked
  //     return true;
  //   } else if(pos3 == 4 && lightOn){ // light on, locked
  //     return true;
  //   } else {
  //     debugPrint("iScooter bridge: _determineLockStatus: unknown state, pos3=$pos3, pos5=$pos5");
  //     return false;
  //   }
  // }

  bool _determineLockStatus(List<int> packet) {
    if (packet.length < 6 || packet[0] != 170 || packet[1] != 3) {
        debugPrint("iScooter bridge: _determineLockStatus: invalid packet");
        return false;
    }

    int pos3 = packet[3]; // relation between light state and lock
    int pos5 = packet[5]; // state of the led (0 = OFF ; 1 = ON)
    bool lightOn = pos5 == 1;

    switch (pos3) {
      case 4:
        // Same state: lock == led
        debugPrint("iScooter bridge: _determineLockStatus: same state pos3=4 ; lock=$lightOn");
        _setReadyState('lock');
        return lightOn;
      case 2:
        // Opposed state: lock != led
        debugPrint("iScooter bridge: _determineLockStatus: opposed states pos3=2 ; lock=${!lightOn}");
        _setReadyState('lock');
        return !lightOn;
      default:
        debugPrint("iScooter bridge: _determineLockStatus: unknown pos3 value: $pos3");
        return false;
    }
  }

  void _setReadyState(String state) {
    if(globals.bridgeReadyStates[state] == true) return;
    if(_setReadyStateTimers[state] != null && _setReadyStateTimers[state]!.isActive) return;

    _setReadyStateTimers[state] = Timer(Duration(milliseconds: 200), () {
      globals.bridgeReadyStates[state] = true;
    });
  }

  void handleStatusPacket(List<int> value) {
    // value[3] seems to be the battery level
    // value[4] seems to tell us if the scooter is moving ahead of the imposed limit
    // value[5] seems to be the speed in km/h
    // value[6] seems to indicate if the system is in metric or imperial mode
    // value[7] seems to be the speed mode and state of the led

    if(value[0] == 170 && value[1] == 161 && value[2] == 6 && (value[4] == 0 || value[4] == 1)) {
      int battery = value[3];

      // Metric or imperial unit
      // if (value[6] == 2 && isMetricSystem) {
      //   isMetricSystem = false;
      // } else if (value[6] == 0 && !isMetricSystem) {
      //   isMetricSystem = true;
      // }

      // Speed in km/h
      int speedRaw = value[5];
      int speed = 0;
      if (speedRaw > 0) {
        speed = (speedRaw / 10).round();
        if (value[4] == 1) speed += 25; // Add 25 km/h if above the limit
      }

      // Speed profile and state of led
      int speedMode = value[7] & 3;
      bool isLedOn = (value[7] & 64) == 64;

      // Update globals data
      if(globals.currentDevice['currentActivity']['battery'] != battery){ // Battery level
        globals.currentDevice['currentActivity']['battery'] = battery;
        globals.socket.add({
          'type': 'databridge',
          'subtype': 'battery',
          'data': globals.currentDevice['currentActivity']['battery']
        });
      }

      if(globals.currentDevice['currentActivity']['speedKmh'] != speed){ // Speed
        globals.currentDevice['currentActivity']['speedKmh'] = speed;
        globals.socket.add({
          'type': 'databridge',
          'subtype': 'speed',
          'data': {
            'speedKmh': speed,
            'source': 'bridge'
          }
        });
      }

      if(globals.currentDevice['currentActivity']['speedMode'] != speedMode) setSpeedMode(speedMode, emitToDevice: false); // Speed profile
      if(globals.currentDevice['currentActivity']['light'] != isLedOn) turnLight(isLedOn, emitToDevice: false); // State of led

      _setReadyState('light');
    }
  }

  void _handleDisconnection(BuildContext? context) async {
    logarte.log("iScooter bridge: handling disconnection");

    if(globals.currentDevice['bluetoothAddress'] != connectedDeviceAddress){
      logarte.log("iScooter bridge: device has changed, skipping reconnection timer and warning");
      return;
    }

    await dispose();

    if(context != null){
      if(context.mounted) showSnackBar(context, "bridges.unknownConnectionError.text".tr(namedArgs: {'additional': globals.settings['disableAutoBluetoothReconnection'] ? "bridges.unknownConnectionError.cannotTryAgain".tr() : "bridges.unknownConnectionError.tryAgain".tr()}));
      if(globals.settings['disableAutoBluetoothReconnection']) return logarte.log("iScooter bridge: auto reconnection is disabled");
      logarte.log("iScooter bridge: reconnecting in 5 seconds...");

      _reconnectionTimer = Timer(Duration(seconds: 5), () {
        if(globals.currentDevice['bluetoothAddress'] != connectedDeviceAddress){
          logarte.log("iScooter bridge: device has changed, skipping reconnection");
          return;
        }

        if(context.mounted){
          logarte.log("iScooter bridge: reconnecting now...");
          init(context);
        } else {
          logarte.log("iScooter bridge: context is not mounted, skipping reconnection");
        }
      });
    }
  }

  Future<bool> dispose() async {
    logarte.log("iScooter bridge: disposing...");

    _reconnectionTimer?.cancel();
    _searchDeviceTimer?.cancel();
    _requestTimer?.cancel();
    _scanResultsSubscription?.cancel();
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    await FlutterBluePlus.stopScan();

    if (_setReadyStateTimers.isNotEmpty) {
      _setReadyStateTimers.forEach((key, timer) => timer.cancel());
      _setReadyStateTimers.clear();
    }

    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        logarte.log("iScooter bridge: Error disconnecting device: $e");
      }
      connectedDevice = null;
    }

    writeCharacteristic = null;
    readCharacteristic = null;

    _saveInBoxTimer?.cancel();
    globals.saveInBox();
    globals.resetCurrentActivityData();

    logarte.log("iScooter bridge: disposed");
    return true;
  }

  Future<void> setSpeedMode(int speed, { bool emitToDevice = true }) async {
    if(emitToDevice) await sendCommand([170, 3, 4, 1, 136, speed, 0, 36 + speed, 187]);
    if(emitToDevice) await sendCommand(utf8.encode("+MODE=$speed").toList());

    globals.socket.add({
      'type': 'databridge',
      'subtype': 'speedMode',
      'data': speed
    });
    globals.currentDevice['currentActivity']['speedMode'] = speed;
  }

  Future<void> setLock(bool state, { bool emitToDevice = true }) async {
    if(emitToDevice) await sendCommand([170, 3, 4, 4, 136, state ? 1 : 0, 0, state ? 32 : 33, 187]);
    if(emitToDevice) await sendCommand(utf8.encode("+LOCK=${state ? "0" : "1"}").toList());

    globals.socket.add({
      'type': 'databridge',
      'subtype': 'locked',
      'data': state
    });
    globals.currentDevice['currentActivity']['locked'] = state;
  }

  Future<void> turnLight(bool state, { bool emitToDevice = true }) async {
    if(emitToDevice) await sendCommand([170, 3, 4, 2, 136, state ? 1 : 0, 0, state ? 38 : 39, 187]);
    if(emitToDevice) await sendCommand(utf8.encode("HLGT=${state ? 1 : 0}").toList());

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