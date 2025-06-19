import 'package:escive/utils/attach_logarte_button.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

PreferredSizeWidget classicAppBar(BuildContext context, String title, { bool showDebugButton = false }) {
  return AppBar(
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark
    ),
    leading: Navigator.of(context).canPop() ? IconButton(
      icon: Icon(Platform.isIOS ? LucideIcons.chevronLeft : LucideIcons.arrowLeft),
      onPressed: () => Navigator.pop(context),
    ) : null,
    title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
    actionsPadding: showDebugButton ? EdgeInsets.only(right: 9) : null,
    actions: !showDebugButton ? [] : [
      IconButton(
        icon: Icon(LucideIcons.wrench, size: 28),
        onPressed: () => attachLogarteButton(context),
      ),
    ],
  );
}