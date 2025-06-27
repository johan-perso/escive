import 'package:escive/main.dart';
import 'package:escive/utils/globals.dart' as globals;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void showSnackBar(BuildContext context, String message, { String icon = 'info' }) {
  logarte.log("showSnackBar: icon = $icon ; message = $message");
  if(!globals.appIsInForeground) return logarte.log("showSnackBar: App is in background, not showing snackbar");

  Color textColor = Theme.of(context).colorScheme.secondary;
  Color iconColor = icon == 'error' ? Colors.red : icon == 'warning' ? Colors.deepOrangeAccent : icon == 'success' ? Colors.green : textColor;

  late IconData iconData;
  if(icon == 'error'){
    iconData = LucideIcons.circleX;
  } else if(icon == 'warning'){
    iconData = LucideIcons.triangleAlert;
  } else if(icon == 'success'){
    iconData = LucideIcons.circleCheck;
  } else {
    iconData = LucideIcons.info;
  }

  final snackBar = SnackBar(
    content: Row(
      children: [
        Icon(iconData, color: iconColor),
        const SizedBox(width: 12),
        Flexible(
          child: Text(message, style: TextStyle(color: textColor, fontWeight: FontWeight.w500))
        ),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    // dismissDirection: isDesktop ? DismissDirection.none : DismissDirection.down,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(15)),
    ),
    duration: Duration(milliseconds: message.length * 70 > 2500 ? message.length * 70 : 2500),
    backgroundColor: Theme.of(context).colorScheme.onSecondary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    width: kIsWeb ? webMaxWidth - 20 : MediaQuery.of(context).size.width > 600 ? 600 : MediaQuery.of(context).size.width - 20,
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}