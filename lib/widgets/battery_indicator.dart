import 'package:escive/main.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'dart:async';
import 'package:flutter/material.dart';

class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({super.key});

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator> with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSubscription;
  late AnimationController _animationController;
  late Animation<double> _animation;
  int batteryLevel = 0;
  String batteryTypeState = 'high';

  @override
  void initState() {
    super.initState();
    batteryLevel = globals.currentDevice['currentActivity']['battery'];

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: batteryLevel.toDouble(),
      end: batteryLevel.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _streamSubscription = globals.socket.stream.listen((event) {
      if (event['type'] == 'refreshStates' && event['value'].contains('batteryIndicator')){
        logarte.log('batteryIndicator: refreshing states');
        if (mounted) setState(() {});
      } else if (event['type'] == 'databridge' && event['subtype'] == 'battery') {
        _updateBatteryLevel(event['data'] as int);
      }
    });
  }

  void _updateBatteryLevel(int newLevel) {
    if (batteryLevel != newLevel) {
      _animation = Tween<double>(
        begin: batteryLevel.toDouble(),
        end: newLevel.toDouble(),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
      
      setState(() {
        batteryLevel = newLevel;
        batteryTypeState = batteryLevel > 60 ? 'high' : batteryLevel > 35 ? 'medium' : batteryLevel > 15 ? 'low' : 'veryLow';
      });
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "$batteryLevel%",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold
          )
        ),

        SizedBox(width: 10),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(2, 3),
                ),
              ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              child: SizedBox(
                height: 25,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Row(
                      children: [
                        Flexible(
                          flex: _animation.value.round(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  batteryTypeState == 'high' ? Color(0xFF1EAA37) : batteryTypeState == 'medium' ? Color(0xFFF9CB43) : batteryTypeState == 'low' ? Colors.deepOrange : Colors.red,
                                  batteryTypeState == 'high' ? Color(0xFF74D134) : batteryTypeState == 'medium' ? Color(0xFFFFD63A) : batteryTypeState == 'low' ? Colors.deepOrangeAccent : Colors.redAccent,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            ),
                          ),
                        ),

                        Flexible(
                          flex: (100 - _animation.value).round(),
                          child: Container(
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}