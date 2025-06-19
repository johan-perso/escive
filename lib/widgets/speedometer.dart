import 'package:escive/main.dart';
import 'package:escive/widgets/warning_light.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

class Speedometer extends StatefulWidget {
  const Speedometer({super.key});

  @override
  State<Speedometer> createState() => _SpeedometerState();
}

class _SpeedometerState extends State<Speedometer> {
  StreamSubscription? _streamSubscription;
  bool showInactivesWarnsLights = globals.settings['showInactivesWarnsLights'] ?? true;
  double currentSpeed = 0;
  double maxSpeed = double.parse((globals.settings['maxRenderedSpeedKmh'] ?? '25') as String);
  late double highSpeed;

  Map warningLights = {
    'bridgeDisconnected': true,
    'positionPrecisionDisabled': false,
    'lowBattery': false,
    'vehicleLightOn': false,
    'vehicleLocked': false
  };

  @override
  void initState() {
    highSpeed = (maxSpeed * 0.85).round().toDouble();

    if(globals.currentDevice['currentActivity']['state'] == 'connected'){
      setState(() { // should be auto emitted and catched by the stream, but the debug bridge is so fast that the speedometer doesn't have the time to process it
        warningLights['bridgeDisconnected'] = false;
      });
    }
    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'refreshStates' && event['value'].contains('speedometer')){
        logarte.log('Speedometer: refreshing states');
        showInactivesWarnsLights = globals.settings['showInactivesWarnsLights'] ?? true;
        maxSpeed = double.parse((globals.settings['maxRenderedSpeedKmh'] ?? '25') as String);
        highSpeed = (maxSpeed * 0.85).round().toDouble();
        setState(() {});
      } else if (event['type'] == 'databridge' && event['subtype'] == 'speed') {
        if(event['data']['source'] == 'bridge' && globals.positionEmitter.currentlyEmittingPositionRealTime){
          logarte.log('Speedometer: received speed from bridge while still being connected to position emitter, ignoring this data');
          return;
        }

        currentSpeed = (event['data']['speedKmh'] as int).toDouble();
        if (mounted) setState(() {});
      } else if (event['type'] == 'databridge' && event['subtype'] == 'warningLight') {
        warningLights[event['data']['name']] = event['data']['value'];
        if (mounted) setState(() {});
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: SfRadialGauge(
        axes: [
          RadialAxis(
            minimum: 0,
            maximum: maxSpeed,
            showLastLabel: true,
            interval: maxSpeed == 25 ? 5 : null,
            maximumLabels: maxSpeed > 60 ? 4 : 3,
            pointers: <GaugePointer>[
              RangePointer(
                value: currentSpeed,
                enableAnimation: true,
                animationDuration: 700,
                animationType: AnimationType.ease,
                gradient: SweepGradient(
                  colors: currentSpeed > highSpeed
                  ? [Color(0xFF6F9CEB), Color(0xFF5887FF), Colors.deepOrange, Colors.deepOrange]
                  : [Color(0xFF6F9CEB), Color(0xFF5887FF)],
                  stops: currentSpeed > highSpeed
                  ? [0.0, 0.8, 0.9, 1.0]
                  : [0.0, 0.8],
                )
              ),
            ],
            ranges: <GaugeRange>[
              GaugeRange(
                startValue: currentSpeed,
                endValue: maxSpeed,
                color: Colors.white10
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      currentSpeed.round().toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 64,
                        color: Colors.grey[900],
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    Text(
                      'km / h',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600
                      ),
                    )
                  ],
                ),
                angle: 90,
                positionFactor: 0.7,
                verticalAlignment: GaugeAlignment.center,
                horizontalAlignment: GaugeAlignment.center
              ),
              GaugeAnnotation(
                widget: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    warningLight(context, enabled: warningLights['bridgeDisconnected'] ?? true, showInactivesWarnsLights: showInactivesWarnsLights, icon: LucideIcons.bluetoothOff500, size: 24, color: Colors.red[600], hint: 'speedometer.warningLights.bridgeDisconnected'.tr()),
                    warningLight(context, enabled: warningLights['positionPrecisionDisabled'] ?? false, showInactivesWarnsLights: showInactivesWarnsLights, icon: LucideIcons.locateOff500, size: 24, color: Colors.red[600], hint: 'speedometer.warningLights.positionPrecisionDisabled'.tr()),
                    warningLight(context, enabled: warningLights['lowBattery'] ?? false, showInactivesWarnsLights: showInactivesWarnsLights, icon: LucideIcons.batteryWarning600, size: 25, color: Colors.red[600], hint: 'speedometer.warningLights.lowBattery'.tr()),
                  ],
                ),
                angle: 90,
                positionFactor: 0.58,
                verticalAlignment: GaugeAlignment.center,
                horizontalAlignment: GaugeAlignment.center
              ),
              GaugeAnnotation(
                widget: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    warningLight(context, enabled: warningLights['vehicleLightOn'] ?? false, showInactivesWarnsLights: showInactivesWarnsLights, icon: LucideIcons.sun500, size: 24, color: Colors.grey[600], hint: 'speedometer.warningLights.vehicleLightOn'.tr()),
                    warningLight(context, enabled: warningLights['vehicleLocked'] ?? false, showInactivesWarnsLights: showInactivesWarnsLights, icon: LucideIcons.key500, size: 22, color: Colors.grey[600], hint: 'speedometer.warningLights.vehicleLocked'.tr()),
                  ],
                ),
                angle: 90,
                positionFactor: 0.77,
                verticalAlignment: GaugeAlignment.center,
                horizontalAlignment: GaugeAlignment.center
              )
            ],
          )
        ],
      ),
    );
  }
}

// return SfRadialGauge(
//   axes: [
//     RadialAxis(
//       minimum: 0,
//       maximum: 45,
//       showLastLabel: true,
//       ranges: <GaugeRange>[
//         GaugeRange(startValue: 0, endValue: 40, color: Colors.white10),
//         GaugeRange(startValue: 40, endValue: 45, color: Colors.red),
//       ],
//       pointers: <GaugePointer>[
//         NeedlePointer(value: 20)
//       ],
//       annotations: <GaugeAnnotation>[
//         GaugeAnnotation(
//           widget: Column(
//             children: [
//               Text('20', style: TextStyle(fontSize: 29, color: Colors.black, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
//               Text('km / h', style: TextStyle(fontSize: 15, color: Colors.grey[900], fontWeight: FontWeight.w600), textAlign: TextAlign.center)
//             ],
//           ),
//           angle: 90,
//           positionFactor: 1.5,
//           verticalAlignment: GaugeAlignment.center,
//           horizontalAlignment: GaugeAlignment.center
//         )
//       ],
//     )
//   ],
// );