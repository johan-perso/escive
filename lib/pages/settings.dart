import 'package:escive/main.dart';
import 'package:escive/utils/refresh_advanced_stats.dart';
import 'package:escive/widgets/classic_app_bar.dart';
import 'package:escive/widgets/settings_tile.dart';
import 'package:escive/widgets/warning_light.dart';
import 'package:escive/utils/changelog.dart';
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/actions_dialog.dart';
import 'package:escive/utils/geolocator.dart';
import 'package:escive/utils/get_app_version.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/widgets/web_viewport_wrapper.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription? _streamSubscription;
  String? appVersion;
  String? appBuild;
  String? overridenLanguage;

  @override
  void initState() {
    getAppVersion().then((value) {
      setState(() {
        appVersion = value['version'];
        appBuild = value['build'];
      });
    });
    globals.refreshSettings();

    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'refreshStates' && event['value'].contains('settings')){
        logarte.log('Settings page: refreshing states');
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
    return WebViewportWrapper(
      child: Scaffold(
        appBar: classicAppBar(context, 'settings.pageTitle'.tr()),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            physics: ClampingScrollPhysics(),
            children: [
              SettingsSection(title: 'settings.display.title'.tr()),

              SettingsTile.toggle(
                context: context,
                title: 'settings.display.showInactivesWarnsLights.title'.tr(),
                subtitle: 'settings.display.showInactivesWarnsLights.subtitle'.tr(),
                value: globals.settings['showInactivesWarnsLights'] ?? true,
                onChanged: (bool? value) {
                  Haptic().light();
                  globals.setSettings('showInactivesWarnsLights', value);
                },
              ),
              SettingsTile.toggle(
                context: context,
                title: 'settings.display.keepScreenTurnedOn.title'.tr(),
                subtitle: 'settings.display.keepScreenTurnedOn.subtitle'.tr(),
                value: globals.settings['keepScreenTurnedOn'] ?? false,
                onChanged: (bool? value) {
                  Haptic().light();
                  globals.setSettings('keepScreenTurnedOn', value);
                  globals.refreshWakelock();
                },
              ),
              SettingsTile.toggle(
                context: context,
                title: 'settings.display.forceScreenBrightnessMax.title'.tr(),
                subtitle: 'settings.display.forceScreenBrightnessMax.subtitle'.tr(),
                value: globals.settings['forceScreenBrightnessMax'] ?? false,
                onChanged: (bool? value) {
                  Haptic().light();
                  globals.setSettings('forceScreenBrightnessMax', value);
                },
              ),
              SettingsTile.select(
                context: context,
                title: 'settings.display.maxRenderedSpeedKmh.title'.tr(),
                subtitle: 'settings.display.maxRenderedSpeedKmh.subtitle'.tr(),
                value: globals.settings['maxRenderedSpeedKmh'] ?? '25',
                values: [
                  {
                    "id": "75",
                    "title": "75 km/h",
                    "subtitle": 'settings.display.maxRenderedSpeedKmh.warning'.tr(),
                  },
                  {
                    "id": "60",
                    "title": "60 km/h",
                  },
                  {
                    "id": "45",
                    "title": "45 km/h",
                  },
                  {
                    "id": "25",
                    "title": "25 km/h",
                  },
                  {
                    "id": "20",
                    "title": "20 km/h",
                  },
                ],
                onChanged: (String? value) async {
                  globals.setSettings('maxRenderedSpeedKmh', value);
                },
              ),
              SettingsTile.select(
                context: context,
                title: 'settings.display.language.title'.tr(),
                subtitle: 'settings.display.language.subtitle'.tr(),
                value: overridenLanguage != null ? overridenLanguage.toString() : context.savedLocale != null ? context.savedLocale.toString() : context.deviceLocale.toString(),
                values: [
                  {
                    "id": "default",
                    "title": 'settings.display.language.values.default'.tr(),
                    "subtitle": 'settings.display.language.values.defaultDescription'.tr(),
                  },
                  {
                    "id": "en_US",
                    "title": 'settings.display.language.values.english'.tr()
                  },
                  {
                    "id": "fr_FR",
                    "title": 'settings.display.language.values.french'.tr()
                  },
                ],
                onChanged: (String? value) async {
                  Locale? locale;
                  if(value == 'default'){
                    logarte.log("Resetting locale");
                    await context.resetLocale();
                    if(context.mounted) overridenLanguage = context.deviceLocale.toString();
                    return;
                  } else if(value == 'en_US'){
                    locale = Locale('en', 'US');
                  } else if(value == 'fr_FR'){
                    locale = Locale('fr', 'FR');
                  } else {
                    logarte.log("Locale $value not found");
                    showSnackBar(context, "Locale $value not found", icon: 'error');
                    return;
                  }

                  logarte.log("Setting locale to $locale");
                  globals.setSettings('customUiLanguage', locale.toString());
                  await context.setLocale(locale);
                  overridenLanguage = value;
                },
              ),

              SizedBox(height: 18),
              SettingsSection(title: "settings.moves.title".tr()),

              SettingsTile.toggle(
                context: context,
                title: "settings.moves.useAdvancedStats.title".tr(),
                subtitle: "settings.moves.useAdvancedStats.subtitle".tr(),
                value: globals.settings['useAdvancedStats'] ?? false,
                onChanged: (bool? value) {
                  Haptic().light();
                  globals.setSettings('useAdvancedStats', value);
                  if(value == true) refreshAdvancedStats();
                },
              ),
              SettingsTile.select(
                context: context,
                title: "settings.moves.usePosition.title".tr(),
                subtitle: "settings.moves.usePosition.subtitle".tr(),
                value: globals.settings['usePosition'] ?? 'never',
                values: [
                  {
                    "id": "always",
                    "title": "settings.moves.usePosition.values.always.title".tr(),
                    "subtitle": "settings.moves.usePosition.values.always.subtitle".tr(),
                  },
                  {
                    "id": "auto",
                    "title": "settings.moves.usePosition.values.auto.title".tr(),
                    "subtitle": "settings.moves.usePosition.values.auto.subtitle".tr(),
                  },
                  {
                    "id": "never",
                    "title": "settings.moves.usePosition.values.never.title".tr(),
                    "subtitle": "settings.moves.usePosition.values.never.subtitle".tr(),
                  },
                ],
                onChanged: (String? value) async {
                  if(value == 'auto' || value == 'always') {
                    var locationPermission = await checkLocationPermission();

                    if(locationPermission != true) {
                      Haptic().warning();
                      globals.setSettings('usePosition', 'never');
                      if(context.mounted) showSnackBar(context, locationPermission, icon: 'warning');
                      redefinePositionWarn();
                      return;
                    }

                    if(value == 'auto' && globals.userDeviceBatteryLow) {
                      logarte.log("Scheduling quick stop for position emitter because user changed precision with position and they don't match anymore");
                      globals.positionEmitter.scheduleStop(delay: Duration(seconds: 0));
                    }
                    else if(value == 'always') { // cancel scheduled stop (if scheduled)
                      globals.positionEmitter.cancelScheduledStop();
                    }
                  } else { // never
                    logarte.log("Scheduling quick stop for position emitter because user disabled the option");
                    globals.positionEmitter.scheduleStop(delay: Duration(seconds: 0));

                    // Disable options that depends on usePrecision
                    globals.setSettings('useSelfEstimatedSpeed', false);
                    globals.setSettings('logsPositionHistory', false);
                    globals.currentDevice['positionHistory'] = [];
                    globals.saveInBox();
                  }

                  globals.setSettings('usePosition', value);
                  redefinePositionWarn();
                },
              ),
              SettingsTile.toggle(
                context: context,
                title: "settings.moves.logsPositionHistory.title".tr(),
                subtitle: "settings.moves.logsPositionHistory.subtitle".tr(),
                value: globals.settings['logsPositionHistory'] ?? false,
                onChanged: (bool? value) {
                  if(value == true && globals.settings['usePosition'] == 'never') {
                    Haptic().warning();
                    showSnackBar(context, "settings.moves.logsPositionHistory.usePositionMustBeEnabled".tr(), icon: 'warning');
                    redefinePositionWarn();
                    return;
                  }
                  if(value == true && globals.settings['enableDashboardWidgets'] == false) {
                    Haptic().warning();
                    showSnackBar(context, "settings.moves.logsPositionHistory.widgetsMustBeEnabled".tr(), icon: 'warning');
                    redefinePositionWarn();
                    return;
                  }

                  if(value == false){
                    globals.currentDevice['positionHistory'] = [];
                    globals.saveInBox();
                  }

                  Haptic().light();
                  globals.setSettings('logsPositionHistory', value);
                  redefinePositionWarn();
                },
              ),
              SettingsTile.toggle(
                context: context,
                title: "settings.moves.useSelfEstimatedSpeed.title".tr(),
                subtitle: "settings.moves.useSelfEstimatedSpeed.subtitle".tr(),
                value: globals.settings['useSelfEstimatedSpeed'] ?? false,
                onChanged: (bool? value) {
                  if(value == true && globals.settings['usePosition'] == 'never') {
                    Haptic().warning();
                    showSnackBar(context, "settings.moves.useSelfEstimatedSpeed.usePositionMustBeEnabled".tr(), icon: 'warning');
                    redefinePositionWarn();
                    return;
                  }

                  Haptic().light();
                  globals.setSettings('useSelfEstimatedSpeed', value);
                  redefinePositionWarn();
                },
              ),

              SizedBox(height: 18),
              SettingsSection(title: "settings.dashboard.title".tr()),

              SettingsTile.toggle(
                context: context,
                title: "settings.dashboard.enableDashboardWidgets.title".tr(),
                subtitle: "settings.dashboard.enableDashboardWidgets.subtitle".tr(),
                value: globals.settings['enableDashboardWidgets'] ?? false,
                onChanged: (bool? value) async {
                  if(kIsWeb || !Platform.isAndroid) {
                    Haptic().warning();
                    showSnackBar(context, "settings.dashboard.enableDashboardWidgets.platformCompatibility".tr(), icon: 'warning');
                    return;
                  }

                  bool gotPermission = await globals.musicPlayerHelper.checkPermissions(openSettings: false);
                  if(!gotPermission) {
                    if(context.mounted) {
                      return actionsDialog(
                        context,
                        title: "settings.dashboard.enableDashboardWidgets.permissionMissing.dialogTitle".tr(),
                        content: "settings.dashboard.enableDashboardWidgets.permissionMissing.dialogContent".tr(),
                        haptic: 'light',
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
                            child: Text("general.cancel".tr()),
                            onPressed: () {
                              Haptic().light();
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.blue[500]),
                            child: Text("general.allow".tr()),
                            onPressed: () {
                              Haptic().light();
                              globals.musicPlayerHelper.checkPermissions(openSettings: true);
                              Navigator.of(context).pop();
                            },
                          ),
                        ]
                      );
                    }
                  }

                  Haptic().light();
                  globals.setSettings('enableDashboardWidgets', value);

                  if(context.mounted) askRestartApp(context);
                },
              ),

              SizedBox(height: 18),
              SettingsSection(title: "settings.dangerZone.title".tr()),

              SettingsTile.action(
                context: context,
                title: "settings.dangerZone.resetStats.title".tr(),
                isDangerous: true,
                onChanged: (bool? value) {
                  actionsDialog(
                    context,
                    title: "settings.dangerZone.resetStats.confirmation.dialogTitle".tr(),
                    content: "settings.dangerZone.resetStats.confirmation.dialogContent".tr(),
                    haptic: 'warning',
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
                        child: Text("general.cancel".tr()),
                        onPressed: () {
                          Haptic().light();
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red[500]),
                        child: Text("general.confirm".tr()),
                        onPressed: () {
                          // box.erase();
                          // setState(() {});
                          Haptic().success();
                          Navigator.of(context).pop();
                        },
                      ),
                    ]
                  );
                },
              ),

              SettingsTile.action(
                context: context,
                title: "settings.dangerZone.resetData.title".tr(),
                subtitle: "settings.dangerZone.resetData.subtitle".tr(),
                isDangerous: true,
                onChanged: (bool? value) {
                  actionsDialog(
                    context,
                    title: "settings.dangerZone.resetData.confirmation.dialogTitle".tr(),
                    content: "settings.dangerZone.resetData.confirmation.dialogContent".tr(),
                    haptic: 'warning',
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
                        child: Text("general.cancel".tr()),
                        onPressed: () {
                          Haptic().light();
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red[500]),
                        child: Text("general.confirm".tr()),
                        onPressed: () async {
                          try {
                            await globals.bridge!.dispose();
                          } catch (e) {
                            logarte.log("Error while disposing bridge: $e");
                          }

                          globals.settings = {};
                          globals.selectedDeviceId = '';
                          globals.currentDevice = {};
                          globals.devices = [];

                          await globals.box.erase();

                          Haptic().success();
                          if(!context.mounted) return;
                          Navigator.of(context).pop();
                          Phoenix.rebirth(context);
                        },
                      ),
                    ]
                  );
                },
              ),

              SizedBox(height: 24),
              GestureDetector(
                onTap: () => showChangelogModal(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Text("eScive${appVersion != null ? ' v$appVersion' : ''}${appBuild != null && appBuild != appVersion ? ' (${kReleaseMode ? '' : 'Debug '}#$appBuild)' : ''}", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                  ],
                ),
              ),
              Text("settings.footerDev".tr(), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),

              const SizedBox(height: 2),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Haptic().light();
                      launchUrl(Uri.parse('https://github.com/johan-perso/escive'), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(LucideIcons.github),
                    color: Theme.of(context).colorScheme.primary
                  ),
                  IconButton(
                    onPressed: () {
                      Haptic().light();
                      launchUrl(Uri.parse('https://twitter.com/johan_stickman'), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(LucideIcons.twitter),
                    color: Theme.of(context).colorScheme.primary
                  ),
                  IconButton(
                    onPressed: () {
                      Haptic().light();
                      launchUrl(Uri.parse('https://johanstick.fr/#donate'), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(LucideIcons.circleDollarSign),
                    color: Theme.of(context).colorScheme.primary
                  ),
                ]
              ),

              const SizedBox(height: 18),
            ],
          ),
        )
      )
    );
  }
}