import 'package:escive/main.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/haptic.dart';
import 'package:escive/widgets/artwork.dart';

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:universal_io/io.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:system_media_controller/system_media_controller.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

class MusicPlayerHelper {
  static const platform = MethodChannel('music_status');
  Timer? _timer;
  Map currentDetails = {};
  int connectedCount = 0;
  bool isRefreshing = false;
  bool hasRefreshedOnce = false;

  String jsonEncodedDefaultDetails = '';
  Map<String, dynamic> getDefaultDetails() {
    return {
      'title': 'N/A',
      'artist': 'N/A',
      'album': 'N/A',
      'progress': -1,
      'duration': -1,
      'state': 'N/A',
      'source': 'N/A',
      'artwork': null,
    };
  }

  Future<bool> checkPermissions({ bool openSettings = false }) async {
    if(Platform.isAndroid){
      try {
        final bool isEnabled = await platform.invokeMethod('isNotificationListenerEnabled');
        if (!isEnabled) {
          if(openSettings) await platform.invokeMethod('openNotificationListenerSettings');
          return false;
        }
        return true;
      } catch (e) {
        logarte.log("Error checking notification listener permission: $e");
        return false;
      }
    }

    return true;
  }

  void _refreshStates(){
    globals.refreshStates(['home', 'musicPlayer']);
  }

  void refreshDetails() async {
    if(jsonEncodedDefaultDetails.isEmpty) jsonEncodedDefaultDetails = jsonEncode(getDefaultDetails());
    if(currentDetails.isEmpty) currentDetails = getDefaultDetails();
    Map oldDetails = Map<String, dynamic>.from(currentDetails);

    try {
      final response = await platform.invokeMethod('getCurrentMusicStatus');
      if(response == null){
        currentDetails['state'] = 'paused';
      } else {
        currentDetails = Map<String, dynamic>.from(response);
      }

      if(String.fromCharCodes(oldDetails['artwork']) != String.fromCharCodes(currentDetails['artwork']) || (jsonEncode(oldDetails) == jsonEncodedDefaultDetails && (jsonEncode(currentDetails) != jsonEncodedDefaultDetails) || !hasRefreshedOnce)){
        globals.refreshStates(['musicPlayer', 'home', 'artwork']);
      } else if(oldDetails['title'] != currentDetails['title'] || oldDetails['artist'] != currentDetails['artist'] || oldDetails['album'] != currentDetails['album'] || oldDetails['state'] != currentDetails['state'] || oldDetails['source'] != currentDetails['source']){
        globals.refreshStates(['musicPlayer', 'home']);
      } else if(oldDetails['progress'] != currentDetails['progress'] || oldDetails['duration'] != currentDetails['duration']){
        globals.refreshStates(['musicPlayer']); // we only have to refresh the player if progress change
      }

      hasRefreshedOnce = true;
    } catch (e) {
      logarte.log("Unable to call platform method 'getCurrentMusicStatus': $e"); // "type 'Null is not a subtype ..." is normal when no music playing
    }
  }

  void control(String action) async {
    if(action == 'play'){
      SystemMediaController().play();
      currentDetails['state'] = 'paused';
      _refreshStates();
    } else if(action == 'pause'){
      SystemMediaController().pause();
      currentDetails['state'] = 'playing';
      _refreshStates();
    } else if(action == 'skipNext'){
      SystemMediaController().skipNext();
      _refreshStates();
    } else if(action == 'skipPrevious'){
      SystemMediaController().skipPrevious();
      _refreshStates();
    } else if(action == 'volumeDown'){
      double currentVolume = await VolumeController.instance.getVolume();
      double newVolume = currentVolume - 0.1;
      await VolumeController.instance.setVolume(newVolume < 0 ? 0 : newVolume);
    } else if(action == 'volumeUp'){
      double currentVolume = await VolumeController.instance.getVolume();
      double newVolume = currentVolume + 0.1;
      await VolumeController.instance.setVolume(newVolume > 1 ? 1 : newVolume);
    } else {
      logarte.log("MusicPlayerHelper: Unknown action used: $action");
    }
  }

  Future<String> init({ bool openSettingsForPermission = false }) async {
    if(globals.settings['enableDashboardWidgets'] != true){
      logarte.log("Music player was called to initialize, but it's disabled in settings");
      return "";
    }

    logarte.log("Music player was called to initialize, adding one connection (from $connectedCount to ${connectedCount + 1})");
    connectedCount++;

    bool gotPermission = await checkPermissions(openSettings: openSettingsForPermission);
    if(!gotPermission){
      logarte.log("Unable to get music player permissions");
      return "musicPlayer.permissionMissing".tr();
    }

    if(!isRefreshing){
      isRefreshing = true;
      logarte.log("Music player was not already refreshing, starting period refresh now");
      refreshDetails();
      _timer = Timer.periodic(Duration(milliseconds: 1200), (_) => refreshDetails());
    }

    return "";
  }

  void dispose() {
    logarte.log("Music player was called to dispose, removing one connection (from $connectedCount to ${connectedCount - 1})");
    connectedCount--;
    if(connectedCount == 0 && _timer != null){
      logarte.log("Last connection to music player got disposed, stopping period refresh now");
      isRefreshing = false;
      _timer?.cancel();
      _timer = null;
    }
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'refreshStates' && event['value'].contains('musicPlayer')){
        logarte.log('musicPlayer page: refreshing states');
        if (mounted) setState(() {});
      }
    });

    super.initState();
    globals.musicPlayerHelper.init(openSettingsForPermission: true);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    globals.musicPlayerHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? source = globals.musicPlayerHelper.currentDetails['source'];
    String? title = globals.musicPlayerHelper.currentDetails['title'];
    String? artist = globals.musicPlayerHelper.currentDetails['artist'];

    return Material(
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Grab"
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  height: 3,
                  width: 112,
                  margin: const EdgeInsets.only(bottom: 28),
                ),
              ),

              // Cover
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardTheme.color,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  onTap: () {
                    Haptic().light();
                    String action = globals.musicPlayerHelper.currentDetails['state'] == 'playing' ? 'pause' : 'play';
                    globals.musicPlayerHelper.control(action);
                  },
                  onDoubleTap: () {
                    Haptic().light();
                    Haptic().light();
                    globals.musicPlayerHelper.control('skipNext');
                  },
                  onLongPress: () {
                    Haptic().heavy();
                    globals.musicPlayerHelper.control('skipPrevious');
                  },
                  child: globals.musicPlayerHelper.currentDetails['artwork'] is Uint8List && globals.musicPlayerHelper.currentDetails['artwork'].isNotEmpty
                    ? ArtworkWidget()
                    : Icon(LucideIcons.music, size: 32, color: Colors.grey[500])
                ),
              ),

              SizedBox(height: 32),

              // Music details
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name of the song
                  Text(
                    title == null || title == 'N/A' ? "musicPlayer.idleTitle".tr() : title,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 2),

                  // Platform name + artist name
                  Row(
                    children: [
                      // Platform name (chip)
                      if (source != null && source != 'N/A' && _getSourceName().isNotEmpty) GestureDetector(
                        onTap: () async {
                          Haptic().light();
                          try {
                            await InstalledApps.startApp(source);
                            logarte.log("Opening app $source");
                          } catch (e) {
                            logarte.log("An error occured while opening the app \"$source\" : $e");
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _getSourceColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getSourceColor().withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getSourceName(),
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getSourceColor(),
                            ),
                          ),
                        ),
                      ),
                      
                      // Artist name
                      Expanded(
                        child: Text(
                          artist == null || artist == 'N/A' ? "musicPlayer.idleSubtitle".tr() : artist,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Progress bar
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _getProgressValue(),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(12),
                      ),

                      SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        spacing: 4,
                        children: [
                          Text(
                            _formatTime(globals.musicPlayerHelper.currentDetails['progress'] ?? 0),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          Text(
                            _formatTime(globals.musicPlayerHelper.currentDetails['progress'] ?? 0, showRemaining: true, totalDuration: globals.musicPlayerHelper.currentDetails['duration'] ?? 0),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Media controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: IconButton(
                      onPressed: () {
                        Haptic().light();
                        globals.musicPlayerHelper.control('skipPrevious');
                      },
                      icon: Icon(
                        Platform.isIOS ? CupertinoIcons.backward_fill : LucideIcons.skipBack500,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),

                  SizedBox(width: 20),

                  SizedBox(
                    width: 54,
                    height: 54,
                    child: IconButton(
                      onPressed: () {
                        Haptic().light();
                        String action = globals.musicPlayerHelper.currentDetails['state'] == 'playing' ? 'pause' : 'play';
                        globals.musicPlayerHelper.control(action);
                      },
                      icon: Icon(
                        globals.musicPlayerHelper.currentDetails['state'] == 'playing'
                          ? Platform.isIOS ? CupertinoIcons.pause_fill : LucideIcons.pause
                          : Platform.isIOS ? CupertinoIcons.play_fill : LucideIcons.play500,
                        color: Colors.black87,
                        size: Platform.isIOS ? 34 : globals.musicPlayerHelper.currentDetails['state'] == 'playing' ? 28 : 24,
                      ),
                    ),
                  ),

                  SizedBox(width: 20),

                  SizedBox(
                    width: 54,
                    height: 54,
                    child: IconButton(
                      onPressed: () {
                        Haptic().light();
                        globals.musicPlayerHelper.control('skipNext');
                      },
                      icon: Icon(
                        Platform.isIOS ? CupertinoIcons.forward_fill : LucideIcons.skipForward500,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 2),

              // Volume controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: IconButton(
                      onPressed: () {
                        Haptic().light();
                        globals.musicPlayerHelper.control('volumeDown');
                      },
                      icon: Icon(
                        Platform.isIOS ? CupertinoIcons.volume_down : LucideIcons.volume1,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),

                  SizedBox(width: 32),

                  SizedBox(
                    width: 54,
                    height: 54,
                    child: IconButton(
                      onPressed: () {
                        Haptic().light();
                        globals.musicPlayerHelper.control('volumeUp');
                      },
                      icon: Icon(
                        Platform.isIOS ? CupertinoIcons.volume_up : LucideIcons.volume2,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getProgressValue() {
    int progress = globals.musicPlayerHelper.currentDetails['progress'] ?? 0;
    int duration = globals.musicPlayerHelper.currentDetails['duration'] ?? 1;
    if (duration <= 0) return 0;
    return (progress / duration).clamp(0.0, 1.0);
  }

  String _formatTime(int milliseconds, { bool showRemaining = false, int totalDuration = 0 }) {
    if (showRemaining) {
      int remainingMs = totalDuration - milliseconds;

      if (remainingMs <= 0) {
        if (totalDuration < 3600000) {
          return "0:00";
        } else {
          return "0:00:00";
        }
      }

      int remainingSeconds = (remainingMs / 1000).round();
      int minutes = remainingSeconds ~/ 60;
      int seconds = remainingSeconds % 60;

      if (totalDuration < 3600000) { // less than an hour
        return "-$minutes:${seconds.toString().padLeft(2, '0')}";
      } else {
        int hours = minutes ~/ 60;
        minutes = minutes % 60;
        return "-$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      }
    } else { // show elapsed time
      int seconds = (milliseconds / 1000).round();
      int minutes = seconds ~/ 60;
      seconds = seconds % 60;

      if (milliseconds < 3600000) { // less then an hour
        return "$minutes:${seconds.toString().padLeft(2, '0')}";
      } else {
        int hours = minutes ~/ 60;
        minutes = minutes % 60;
        return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      }
    }
  }

  Color _getSourceColor() {
    String source = globals.musicPlayerHelper.currentDetails['source'] ?? '';
    if (source.contains('spotify')) return Color(0xFF1DB954);
    if (source.contains('apple')) return Color(0xFFFB415B);
    if (source.contains('youtube')) return Color(0xFFFF0000);
    if (source.contains('soundcloud')) return Color(0xFFFF5500);
    if (source.contains('deezer')) return Color(0xFF9F54F3);
    if (source.contains('tidal')) return Color(0xFF000000);
    return Colors.grey[700]!;
  }

  String _getSourceName() {
    String source = globals.musicPlayerHelper.currentDetails['source'] ?? '';
    if (source.contains('spotify')) return 'SPOTIFY';
    if (source.contains('apple')) return 'APPLE MUSIC';
    if (source.contains('youtube')) return 'YT MUSIC';
    if (source.contains('soundcloud')) return 'SOUNDCLOUD';
    if (source.contains('deezer')) return 'DEEZER';
    if (source.contains('tidal')) return 'TIDAL';
    return '';
  }
}