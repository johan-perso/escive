import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/show_snackbar.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cupertino_onboarding/cupertino_onboarding.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

Map currentChangelog = { // example
  "version": "0.1.0",
  "features": [
    {
      "title": "Music Widget",
      "description": "You can now manage the music you're listening to, directly from eScive, without having to quit the app. Always take precautions when riding!",
      "icon": Icon(LucideIcons.music4)
    }
  ]
};

void showChangelogModal(BuildContext context) async {
  return; // we're still in beta

  if(globals.screenHeight < 500) {
    showSnackBar(context, "changelog.heightMinUnrespected".tr(), icon: "warning");
    Haptic().warning();
    return;
  }

  Haptic().light();
  await showCupertinoModalBottomSheet(
    duration: const Duration(milliseconds: 300),
    context: context,
    builder: (context) {
      return Material(
        color: Colors.transparent,
        child: Container(
          constraints: Platform.isIOS ? null : BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - 120,
          ),
          child: CupertinoChangelogHelper(),
        ),
      );
    },
  );
  Haptic().light();
}

class CupertinoChangelogHelper extends StatefulWidget {
  const CupertinoChangelogHelper({super.key});

  @override
  State<CupertinoChangelogHelper> createState() => _CupertinoChangelogHelperState();
}

class _CupertinoChangelogHelperState extends State<CupertinoChangelogHelper> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  Widget _buildTitleText(Color primaryColor) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        children: [
          TextSpan(
            text: "changelog.titlePrefix".tr(),
            style: TextStyle(
              color: Colors.black,
              letterSpacing: -0.9
            ),
          ),
          TextSpan(
            text: "eScive",
            style: TextStyle(
              fontFamily: 'Sora',
              letterSpacing: -0.8,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 1.3),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                  ],
                ).createShader(Rect.fromLTWH(0, 0, 200, 70))
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoOnboarding(
      onPressedOnLastPage: () => Navigator.pop(context),
      bottomButtonChild: Text("general.continue".tr()),
      bottomButtonBorderRadius: Platform.isIOS ? null : BorderRadius.circular(64),
      bottomButtonPadding: EdgeInsets.symmetric(horizontal: Platform.isIOS ? 22 : 36, vertical: Platform.isIOS ? 60 : 40),
      pages: [
        WhatsNewPage(
          title: _buildTitleText(Theme.of(context).colorScheme.primary),
          features: ((currentChangelog['features'] ?? []) as List).map((feature) {
            return WhatsNewFeature(
              icon: feature['icon'] ?? Icon(LucideIcons.circleHelp),
              title: Text(feature['title'] ?? "? Title"),
              description: Text(feature['description'] ?? "? Description"),
            );
          }).toList(),
        ),
      ],
    );
  }
}