import 'package:escive/main.dart';

import 'package:flutter/services.dart';

final MethodChannel _channel = MethodChannel('escive_native_bridge');
  
Future<void> sendKustomVariable({
  required String variableName,
  required String variableValue,
}) async {
  try {
    logarte.log("sendKustomVariable: Sending: varName = $variableName ; varValue = $variableValue");
    await _channel.invokeMethod('sendKustomVariable', {
      'extName': 'escive',
      'varName': variableName,
      'varValue': variableValue,
    });
    logarte.log('sendKustomVariable: Should be sent with success, extName = escive');
  } catch (e) {
    logarte.log('sendKustomVariable: failed to send: $e');
  }
}