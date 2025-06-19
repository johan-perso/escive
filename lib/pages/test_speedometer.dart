import 'package:escive/utils/globals.dart' as globals;

import 'dart:async';
import 'package:flutter/material.dart';

class TestSpeedometer extends StatefulWidget {
  const TestSpeedometer({super.key});

  @override
  State<TestSpeedometer> createState() => _TestSpeedometerState();
}

class _TestSpeedometerState extends State<TestSpeedometer> with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSubscription;
  List history = [];
  Map currentSpeed = {
    "bridge": -1,
    "gps": -1
  };

  @override
  void initState() {
    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'databridge' && event['subtype'] == 'speed'){
        double newSpeed = (event['data']['speedKmh'] as int).toDouble();
        currentSpeed[event['data']['source']] = newSpeed;
        history.insert(0, '$newSpeed km/h (${event['data']['precision']}) (${event['data']['source']})');
        if(history.length > 50) history.removeAt(history.length - 1);
        setState(() {});
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 32, right: 32, top: 12),
          child: SingleChildScrollView(
            child: Column(
              spacing: 10,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From bridge:',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 0
                          )
                        ),
                        Text(
                          '${currentSpeed['bridge']}',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 48,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            height: 0
                          )
                        ),
                      ],
                    ),

                    Spacer(),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'From GPS:',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 0
                          )
                        ),
                        Text(
                          '${currentSpeed['gps']}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 48,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            height: 0
                          )
                        ),
                      ],
                    ),
                  ]
                ),

                Divider(),

                Container(
                  constraints: BoxConstraints(minWidth: double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('History:', textAlign: TextAlign.left),
                      Text(history.join('\n'), textAlign: TextAlign.left),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
