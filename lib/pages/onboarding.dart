import 'package:escive/main.dart';
import 'package:escive/pages/add_device.dart';
import 'package:escive/utils/actions_dialog.dart';
import 'package:escive/utils/add_saved_device.dart';
import 'package:escive/utils/attach_logarte_button.dart';
import 'package:escive/utils/check_bluetooth_permission.dart';
import 'package:escive/utils/get_app_version.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/widgets/web_viewport_wrapper.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pattern_box/pattern_box.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSubscription;
  String appVersion = 'N/A';
  String appBuild = '-1';
  double backgroundPatternAlpha = 0.1;
  double backgroundPatternThickness = 4.0;
  bool backgroundPatternDirectionUp = true;
  Timer? _backgroundPatternTimer;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    getAppVersion().then((value) {
      setState(() {
        appVersion = value['version'];
        appBuild = value['build'];
      });
    });

    _buttonAnimationController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );
    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    ));

    _streamSubscription = globals.socket.stream.listen((event) {
      if(event['type'] == 'refreshStates' && event['value'].contains('onboarding')){
        logarte.log('Onboarding page: refreshing states');
        if (mounted) setState(() {});
      }
    });

    _backgroundPatternTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (mounted) {
        setState(() {
          if(backgroundPatternDirectionUp){
            backgroundPatternAlpha += 0.01;
            backgroundPatternThickness += 0.15;
          } else {
            backgroundPatternAlpha -= 0.01;
            backgroundPatternThickness -= 0.15;
          }
          debugPrint('backgroundPatternAlpha: $backgroundPatternAlpha');
          debugPrint('backgroundPatternThickness: $backgroundPatternThickness');
          debugPrint('backgroundPatternDirectionUp: $backgroundPatternDirectionUp');

          if(backgroundPatternAlpha >= 0.15) backgroundPatternDirectionUp = false;
          if(backgroundPatternAlpha <= 0.1) backgroundPatternDirectionUp = true;
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _backgroundPatternTimer?.cancel();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  Widget _buildTitleText(Color primaryColor) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
        children: [
          TextSpan(
            text: 'onboarding.welcome'.tr(),
            style: TextStyle(
              color: Colors.black,
            ),
          ),
          TextSpan(
            text: 'eScive',
            style: TextStyle(
              fontFamily: 'Sora',
              letterSpacing: -0.8,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.8),
                  ],
                ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenSize = MediaQuery.of(context).size;

    return WebViewportWrapper(
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient in the top background
            Container(
              decoration: BoxDecoration(
                gradient: globals.isLandscape ? null : RadialGradient(
                  center: Alignment.topCenter,
                  focal: Alignment.topCenter,
                  focalRadius: 0.1,
                  radius: 3,
                  colors: [
                    primaryColor.withValues(alpha: 0.5),
                    // primaryColor.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white,
                  ],
                  stops: [0, 0.3, 0.4],
                  // stops: [0, 0.1, 0.3, 0.4],
                ),
              ),
            ),

            // Animated pattern in background
            CustomPaint(
              size: Size(screenSize.width, screenSize.height),
              painter: DiamondPainter(
                color: primaryColor.withValues(alpha: backgroundPatternAlpha),
                thickness: backgroundPatternThickness,
                gap: 20,
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Upper section
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            globals.isLandscape ? SizedBox() : Image.asset(
                              'lib/assets/semitransparent_scooter.png',
                              height: 200,
                              width: 200,
                              fit: BoxFit.contain,
                            ),

                            SizedBox(height: globals.isLandscape ? 0 : 40),
                            _buildTitleText(primaryColor),
                            const SizedBox(height: 12),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 36.0),
                              child: Text(
                                'onboarding.description'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Lower section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _buttonScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _buttonScaleAnimation.value,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: 500,
                                ),
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      primaryColor.withValues(alpha: 0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(64),
                                ),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    _buttonAnimationController.forward().then((_) {
                                      _buttonAnimationController.reverse();
                                    });

                                    Haptic().light();
                                    bool hasPermission = await checkBluetoothPermission(context);

                                    if (hasPermission && context.mounted){
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
                                        (Route<dynamic> route) => false
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(27.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        LucideIcons.bluetooth,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        "onboarding.ctaButton".tr(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 22),

                        GestureDetector(
                          onTap: () => attachLogarteButton(context),
                          child: Text(
                            'Version $appVersion - Build ${kReleaseMode ? '' : '(Debug) '}#$appBuild',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              height: 1.3,
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        GestureDetector(
                          onTap: () {
                            actionsDialog(
                              context,
                              title: "onboarding.demo.dialogTitle".tr(),
                              content: "onboarding.demo.dialogContent".tr(),
                              haptic: 'light',
                              actions: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
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
                                      child: Text("general.confirm".tr()),
                                      onPressed: () {
                                        Haptic().light();
                                        addSavedDevice(context);
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                ),
                              ]
                            );
                          },
                          child: Text(
                            'onboarding.demo.label'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              height: 1.3,
                            ),
                          ),
                        ),

                        const SizedBox(height: kIsWeb ? 18 : 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
