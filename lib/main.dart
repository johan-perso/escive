import 'package:escive/pages/home.dart';
import 'package:escive/pages/onboarding.dart';
import 'package:escive/pages/logarte_custom_tab.dart';
import 'package:escive/utils/get_app_version.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/refresh_advanced_stats.dart';
import 'package:escive/widgets/warning_light.dart';

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:logarte/logarte.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

double webMaxWidth = 414;
double webMaxHeight = 896;
final mesureStopwatch = Stopwatch()..start();

final Logarte logarte = Logarte(
  ignorePassword: true,
  customTab: const LogarteCustomTab(),
  onRocketLongPressed: (context) async {
    if(context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      logarte.log('Cannot go even further');
    }
  }
);

void main() async {
  debugPrint("TimeMesuring: main.dart: main() was called, elapsed: ${mesureStopwatch.elapsedMilliseconds} ms (start)");

  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('fr', 'FR'),
  ];
  bool isUserLanguageSupported = false;
  String? userLanguage = Platform.localeName.split('_')[0];
  for (Locale locale in supportedLocales) {
    if (locale.languageCode == userLanguage) {
      isUserLanguageSupported = true;
      break;
    }
  }

  debugPrint("User language: $userLanguage");
  if (!isUserLanguageSupported) {
    logarte.log("User language is not supported, using default language (en_US)");
    userLanguage = 'en';
  }

  debugPrint("TimeMesuring: main.dart: start of firsts async operations, elapsed: ${mesureStopwatch.elapsedMilliseconds} ms");

  await localization.EasyLocalization.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  initializeDateFormatting(isUserLanguageSupported ? Platform.localeName : 'en_US', null);

  debugPrint("TimeMesuring: main.dart: start of secondary async operations, elapsed: ${mesureStopwatch.elapsedMilliseconds} ms");

  await dotenv.load(fileName: ".env", isOptional: true);
  await GetStorage.init();
  await getAppVersion(); // establish cache at the start

  debugPrint("TimeMesuring: main.dart: async operations has finished, elapsed: ${mesureStopwatch.elapsedMilliseconds} ms");

  runApp(
    Phoenix(
      child: localization.EasyLocalization(
        supportedLocales: supportedLocales,
        path: 'resources/langs',
        fallbackLocale: Locale('en', 'US'),
        useOnlyLangCode: true,
        child: const MainApp()
      ),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  StreamSubscription? _streamSubscription;

  late Future<void> _initializationFuture;
  bool finishedFirstBuild = false;

  bool forcedBrightnessChangeState = false;
  double forcedBrightnessChangeValue = 0;
  bool hasDrivedOnce = false;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  StreamSubscription<FGBGType>? fgbgSubscription;

  final Battery batteryPlus = Battery();

  ThemeData themeData = ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(primary: Color(0xFF5887FF)),
    brightness: Brightness.light,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: const IconThemeData(
      fill: 0,
      weight: 600,
      opticalSize: 56
    ),
    hintColor: Color(0xFFD3D3D7),
    cardTheme: CardTheme(
      color: Color(0xFFF0F1F7),
      elevation: 0,
    ),
    scaffoldBackgroundColor: Colors.white,
    canvasColor: Colors.white,
    cardColor: Color(0x46474D40),
    splashFactory: Platform.isIOS ? NoSplash.splashFactory : null,
    splashColor: Platform.isIOS ? Colors.transparent : null,
    highlightColor: Platform.isIOS ? Colors.transparent : null,
    fontFamily: Platform.isIOS ? null : 'Inter',
  );

  Future<void> refreshSettingsThenStates() async {
    await globals.refreshSettings();
    await globals.refreshDevices();
    globals.refreshWakelock();
    return;
  }

  void refreshBrightness() {
    if(globals.settings['forceScreenBrightnessMax'] != true){
      if(forcedBrightnessChangeState == true){
        logarte.log('Main: settings forceScreenBrightnessMax is now disabled, resetting brightness');
        ScreenBrightness.instance.resetApplicationScreenBrightness();
        forcedBrightnessChangeState = false;
        forcedBrightnessChangeValue = 0;
      }

      return;
    }

    if(!hasDrivedOnce) return;

    final now = DateTime.now();
    double brightness = now.hour >= 22 || now.hour < 6 ? 0.8 : 1; // 80% between 22h and 6h, else 100%

    try {
      if(globals.currentDevice['currentActivity']['light'].runtimeType == bool && globals.currentDevice['currentActivity']['light'] == true){
        brightness = 1; // bypass if light is turned on: we define as 100%
        logarte.log('Main: bypassing brightness detection because light is turned on');
      } else {
        logarte.log('Main: not bypassing brightness detection because light is not turned on');
      }
    } catch (e) {
      logarte.log('Main: cannot check if light is turned on, cannot bypass brightness detection: $e');
    }

    try {
      if(forcedBrightnessChangeState != true || forcedBrightnessChangeValue != brightness){
        logarte.log('Main: setting brightness to $brightness');
        ScreenBrightness.instance.setApplicationScreenBrightness(brightness);
        forcedBrightnessChangeState = true;
        forcedBrightnessChangeValue = brightness;
      } else {
        logarte.log('Main: cannot set brightness to $brightness, already set to $forcedBrightnessChangeValue');
      }
    } catch (e) {
      logarte.log('Main: cannot set brightness to $brightness, error: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final size = MediaQuery.of(context).size;
    globals.screenWidth = kIsWeb ? webMaxWidth : size.width;
    globals.screenHeight = kIsWeb ? webMaxHeight : size.height;
    globals.isLandscape = kIsWeb ? false : MediaQuery.of(context).orientation == Orientation.landscape;
    globals.refreshStates(['home', 'onboarding', 'addDevice']);

    logarte.log("Screen size: ${globals.screenWidth}x${globals.screenHeight} (${globals.isLandscape ? 'landscape' : 'portrait'})");
  }

  @override
  void initState(){
    debugPrint("TimeMesuring: main.dart: initState() was called, elapsed: ${mesureStopwatch.elapsedMilliseconds} ms");
    super.initState();

    _initializationFuture = refreshSettingsThenStates();

    batteryPlus.batteryLevel.then((int level) {
      logarte.log('Initial battery level: $level%');
      globals.userDeviceBatteryLevel = level;
    });

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black.withValues(alpha: 0.002),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _streamSubscription = globals.socket.stream.listen((event) {
      logarte.log('Received event: ${jsonEncode(event)}');

      if (event['type'] == 'databridge' && event['subtype'] == 'speed' && event['data']['speedKmh'] < 6 && event['data']['source'] == 'bridge') {
        globals.currentDevice['stats']['datas']['lastActivityTimeUpdate'] = null; // force reset of lastActivityTimeUpdate when speed start to be under 6km/h
      }

      if(event['type'] == 'refreshStates' && event['value'].contains('main')){
        logarte.log('Main: refreshing states');
        if (mounted) setState(() {});
      } else if (event['type'] == 'databridge' && event['subtype'] == 'speed' && event['data']['speedKmh'] > 5 && event['data']['source'] == 'bridge') {
        hasDrivedOnce = true;
        refreshBrightness();
        refreshAdvancedStats();

        if(globals.settings['useAdvancedStats'] == true && globals.currentDevice.containsKey('stats')){
          if(!globals.currentDevice['stats']['datas'].containsKey('lastActivityTimeUpdate') || globals.currentDevice['stats']['datas']['lastActivityTimeUpdate'] == null) globals.currentDevice['stats']['datas']['lastActivityTimeUpdate'] = DateTime.now().toIso8601String();
          globals.currentDevice['stats']['totalActivityTimeSecs'] += DateTime.now().difference(DateTime.parse(globals.currentDevice['stats']['datas']['lastActivityTimeUpdate'])).inSeconds; // add difference between now and last check
          globals.currentDevice['stats']['datas']['lastActivityTimeUpdate'] = DateTime.now().toIso8601String();
        }

        // Start emitting position when the device start moving
        if(mounted && context.mounted && globals.positionEmitter.currentlyEmittingPositionRealTime == false){
          globals.positionEmitter.emitCurrentPositionRealTime(context, action: 'start');
        } else if(globals.positionEmitter.currentlyEmittingPositionRealTime == true) {
          globals.positionEmitter.cancelScheduledStop();
        }
      } else if (event['type'] == 'databridge' && ((event['subtype'] == 'speed' && event['data']['speedKmh'] < 1 && event['data']['source'] == 'bridge') || (event['subtype'] == 'state' && event['data'] != 'connected'))) {
        // Stop emitting position when the device stop moving or get disconnected (restart counting when moves again or get connected again)
        if(globals.positionEmitter.currentlyEmittingPositionRealTime == true){
          globals.positionEmitter.scheduleStop(delay: Duration(seconds: event['subtype'] == 'state' && event['data'] != 'connected' ? 0 : 60));
        }
      } else if (event['type'] == 'databridge' && event['subtype'] == 'light') {
        globals.bridge.setWarningLight('vehicleLightOn', event['data']);
        refreshBrightness();
      } else if (event['type'] == 'databridge' && event['subtype'] == 'locked') {
        globals.bridge.setWarningLight('vehicleLocked', event['data']);
      } else if (event['type'] == 'databridge' && event['subtype'] == 'battery') {
        redefineBatteryWarn();
      }
    });

    batteryPlus.onBatteryStateChanged.listen((BatteryState state) async {
      logarte.log('Battery state: $state');
      globals.userDeviceBatteryLevel = await batteryPlus.batteryLevel;

      if(globals.userDeviceBatteryLevel < 30) { // less than 30%
        globals.userDeviceBatteryLow = true;
        if(globals.settings['usePosition'] == 'auto') globals.positionEmitter.scheduleStop(delay: Duration(seconds: 0)); // disable the data precision when battery is low
      } else {
        globals.userDeviceBatteryLow = false;
      }

      redefineBatteryWarn();
    });

    globals.appIsInForeground = FGBGEvents.last == FGBGType.foreground;
    logarte.log('FGBG: Initial event: ${globals.appIsInForeground ? 'foreground' : 'background'}');
    fgbgSubscription = FGBGEvents.instance.stream.listen((event) {
      globals.appIsInForeground = event == FGBGType.foreground;
      logarte.log('FGBG: Received event: ${globals.appIsInForeground ? 'foreground' : 'background'}');
    });

    initDeepLinks();
    debugPrint("TimeMesuring: main.dart: initState() finished his tasks, elapsed: ${mesureStopwatch.elapsedMilliseconds} ms");
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _linkSubscription?.cancel();
    fgbgSubscription?.cancel();
    super.dispose();
  }

  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();

    // Listen to new links executions
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) { handleIncomingLink(uri); },
      onError: (err) { logarte.log('DeepLinking: Failed to listen to incoming links: $err'); },
    );

    // Check if the app was opened with a link
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) handleIncomingLink(uri);
    } catch (e) {
      logarte.log('DeepLinking: Failed to check the initial link: $e');
    }
  }

  void handleIncomingLink(Uri uri) {
    List pathSegments = uri.toString().replaceAll('${uri.scheme}://', '').split('/');
    logarte.log("DeepLinking: Received a new link: uri = $uri ; pathSegments = ${pathSegments.join(' , ')}");

    if(uri.scheme != 'escive') return logarte.log("DeepLinking: Received a link that isn't on the valid scheme (${uri.scheme}): $uri");
    if(pathSegments.isEmpty) return logarte.log("DeepLinking: Cancelling because link is empty");

    switch(pathSegments[0]) {
      case 'app':
        Haptic().success();
        break;
      case 'controls':
        switchControlLink(pathSegments);
      default:
        logarte.log("DeepLinking: No action associated with the position 0 of pathSegments: ${pathSegments[0]}");
        Haptic().error();
        break;
    }
  }

  Future<void> waitForState(String state, { int timeout = 25 }) async {
    int waitInterval = 400;
    int waitAttempts = 0; // new attempt every 400ms, so if timeout = 25, we will wait for 25 * 400ms = 10 seconds
    while (globals.bridgeReadyStates[state] != true && waitAttempts < timeout) {
      logarte.log("DeepLinking: Waiting for bridge $state state to be ready... (attempt ${waitAttempts + 1}/$timeout)");
      await Future.delayed(Duration(milliseconds: waitInterval));
      waitAttempts++;
    }

    if (globals.bridgeReadyStates[state] != true) {
      logarte.log("DeepLinking: Bridge $state state not ready after timeout, proceeding anyway");
    } else {
      logarte.log("DeepLinking: Bridge $state state is ready after ${waitAttempts * waitInterval}ms");
    }
  }

  void switchControlLink(List pathSegments) async {
    switch(pathSegments[1]) {
      case 'lock':
        try {
          await waitForState('lock');
          await globals.bridge.setLock(
            pathSegments[2] == 'on' ? true :
            pathSegments[2] == 'off' ? false :
            pathSegments[2] == 'toggle' ? !(globals.currentDevice['currentActivity']?['locked'] ?? false) :
            false
          );
          Haptic().success();
        } catch (e) { Haptic().error(); }
        break;
      case 'light':
        try {
          await waitForState('light');
          await globals.bridge.turnLight(
            pathSegments[2] == 'on' ? true :
            pathSegments[2] == 'off' ? false :
            pathSegments[2] == 'toggle' ? !(globals.currentDevice['currentActivity']?['light'] ?? false) :
            false
          );
          Haptic().success();
        } catch (e) { Haptic().error(); }
        break;
      case 'speed':
        await waitForState('speed');
        try {
          await globals.bridge.setSpeedMode(int.parse(pathSegments[2]));
          Haptic().success();
        } catch (e) { Haptic().error(); }
        break;
      default:
        logarte.log("DeepLinking: No action associated with the position 1 of pathSegments: ${pathSegments[1]}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: themeData,
            home: Scaffold(
              body: Center(
                child: FutureBuilder(
                  // Generally it doesn't even show for 100ms when restarting with Pheonix (without splash screen) (and completly not showing when starting app with splash screen)
                  // The result is that we can see the splash screen for a few moments, before it even start to rotater
                  // So, we will only show the spinner after an entire second
                  future: Future.delayed(Duration(seconds: 1), () => true),
                  builder: (context, delaySnapshot) {
                    return delaySnapshot.connectionState == ConnectionState.done
                      ? CircularProgressIndicator()
                      : SizedBox.shrink();
                  },
                ),
              ),
            ),
          );
        }

        if(!finishedFirstBuild){
          finishedFirstBuild = true;
          logarte.log('Main: finished first build');
          debugPrint("TimeMesuring: main.dart: finished first build, elapsed: ${mesureStopwatch.elapsedMilliseconds} ms (end)");

          if(globals.settings['customUiLanguage'] != null && globals.settings['customUiLanguage'] != ''){
            logarte.log('Main: custom UI language settings is set to ${globals.settings['customUiLanguage']}');
            String languageCode = globals.settings['customUiLanguage'].substring(0, 2);
            String countryCode = globals.settings['customUiLanguage'].substring(3, 5);
            logarte.log('Main: locale will be set to languageCode = $languageCode ; countryCode = $countryCode');
            context.resetLocale().then((value) => {
              if(context.mounted) context.setLocale(Locale(languageCode, countryCode))
            });
          }

          FlutterNativeSplash.remove();
          mesureStopwatch.stop();
        }

        return MaterialApp(
          navigatorObservers: [LogarteNavigatorObserver(logarte)],
          theme: themeData,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: globals.devices.isEmpty ? const OnboardingScreen() : const HomeScreen(),
        );
      },
    );
  }
}