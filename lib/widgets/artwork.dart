import 'package:escive/main.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ArtworkWidget extends StatefulWidget {
  const ArtworkWidget({super.key});

  @override
  ArtworkWidgetState createState() => ArtworkWidgetState();
}

class ArtworkWidgetState extends State<ArtworkWidget> {
  StreamSubscription? _streamSubscription;
  Widget? _cachedImage;

  @override
  void initState() {
    super.initState();

    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'refreshStates' && event['value'].contains('artwork')){
        logarte.log('artwork: refreshing states');
        _buildImageIfNeeded();
        if (mounted) setState(() {});
      }
    });

    _buildImageIfNeeded();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _buildImageIfNeeded() {
    _cachedImage = globals.musicPlayerHelper.currentDetails['artwork'] is Uint8List && globals.musicPlayerHelper.currentDetails['artwork'].isNotEmpty
      ? Image.memory(
          globals.musicPlayerHelper.currentDetails['artwork'],
          cacheHeight: (globals.screenWidth * 0.9).toInt(),
          cacheWidth: (globals.screenWidth * 0.9).toInt(),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          gaplessPlayback: true, // avoid flashing when changing images
          filterQuality: FilterQuality.medium,
        )
      : Container();
  }

  @override
  Widget build(BuildContext context) {
    return _cachedImage ?? Container();
  }
}
