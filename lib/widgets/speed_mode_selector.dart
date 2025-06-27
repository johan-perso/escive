import 'package:escive/main.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class SpeedModeSelector extends StatefulWidget {
  const SpeedModeSelector({super.key});

  @override
  State<SpeedModeSelector> createState() => _SpeedModeSelectorState();
}

class _SpeedModeSelectorState extends State<SpeedModeSelector> {
  StreamSubscription? _streamSubscription;
  int speedMode = 0;
  Map supportedProperties = globals.defaultSupportedProperties;

  @override
  void initState() {
    supportedProperties = globals.currentDevice['supportedProperties'] ?? globals.defaultSupportedProperties;
    super.initState();

    _streamSubscription = globals.socket.stream.listen((event) {
      if (event['type'] == 'refreshStates' && event['value'].contains('speedModeSelector')){
        logarte.log('speedModeSelector: refreshing states');
        if (mounted) setState(() {});
      } else if (event['type'] == 'databridge' && event['subtype'] == 'speedMode') {
        speedMode = event['data'] as int;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void changeSpeedMode(int newSpeed){
    if(newSpeed == speedMode){
      return Haptic().light();
    } else if(newSpeed - 1 == speedMode || newSpeed + 1 == speedMode){
      Haptic().light();
    } else {
      int gap = newSpeed - speedMode;
      if(gap < 0) gap = -gap;
      for(int i = 0; i < gap; i++){
        Future.delayed(Duration(milliseconds: i * 100), () {
          Haptic().click();
        });
      }
      Haptic().light();
    }
    globals.bridge.setSpeedMode(newSpeed);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = constraints.maxWidth / supportedProperties['speedModeLength'];
          final buttonHeight = constraints.maxHeight - (kIsWeb ? 0 : 6);

          return Stack(
            children: [
              // Animated background behind the buttons
              AnimatedPositioned(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: speedMode * buttonWidth,
                child: Container(
                  width: buttonWidth,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),

              // Speed mode buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  supportedProperties['speedModeLength'] > 0 ? Expanded(
                    child: IconButton.filled(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(Colors.transparent),
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        minimumSize: WidgetStateProperty.all(Size(32, 32)),
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(Symbols.directions_walk, size: 24, color: speedMode == 0 ? Colors.grey[800] : Colors.grey[700]),
                      onPressed: () {
                        changeSpeedMode(0);
                        Haptic().click();
                      },
                    ),
                  ) : SizedBox(),

                  supportedProperties['speedModeLength'] > 1 ? Expanded(
                    child: IconButton.filled(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(Colors.transparent),
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        minimumSize: WidgetStateProperty.all(Size(32, 32)),
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(Symbols.temp_preferences_eco, size: 24, color: speedMode == 1 ? Colors.grey[800] : Colors.grey[700]),
                      onPressed: () {
                        changeSpeedMode(1);
                        Haptic().click();
                      },
                    ),
                  ) : SizedBox(),

                  supportedProperties['speedModeLength'] > 2 ? Expanded(
                    child: IconButton.filled(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(Colors.transparent),
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        minimumSize: WidgetStateProperty.all(Size(32, 32)),
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(Symbols.wind_power, size: 24, color: speedMode == 2 ? Colors.grey[800] : Colors.grey[700]),
                      onPressed: () {
                        changeSpeedMode(2);
                        Haptic().click();
                      },
                    ),
                  ) : SizedBox(),

                  supportedProperties['speedModeLength'] > 3 ? Expanded(
                    child: IconButton.filled(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(Colors.transparent),
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        minimumSize: WidgetStateProperty.all(Size(32, 32)),
                      ),
                      icon: Icon(Symbols.bolt, size: 24, color: speedMode == 3 ? Colors.grey[800] : Colors.grey[700]),
                      onPressed: () {
                        changeSpeedMode(3);
                        Haptic().click();
                      },
                    ),
                  ) : SizedBox(),
                ],
              ),
            ],
          );
        }
      )
    );
  }
}