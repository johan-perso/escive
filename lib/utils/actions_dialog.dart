import 'package:escive/main.dart';
import 'package:escive/utils/haptic.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

void actionsDialog(BuildContext context, { bool canBeIgnored = true, String title = 'N/A', String content = 'N/A', String haptic = 'warning', EdgeInsets? actionsPadding, List<Widget>? actions }) {
  if(haptic == 'warning') Haptic().warning();
  if(haptic == 'light') Haptic().light();
  if(haptic == 'error') Haptic().error();
  if(haptic == 'success') Haptic().success();

  double minWidth = MediaQuery.of(context).size.width * 0.8;

  AlertDialog dialog = AlertDialog(
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    backgroundColor: Colors.white,
    titleTextStyle: TextStyle(color: Colors.grey[900], fontSize: 18, fontWeight: FontWeight.w600),
    shadowColor: Colors.grey[500],
    title: Text(title),
    content: ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth < 500 ? minWidth : 500, maxWidth: 500),
      child: SingleChildScrollView(
        child: Text(content)
      ),
    ),
    actionsPadding: actionsPadding ?? const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 14),
    actions: actions
  );

  showDialog(
    context: context,
    barrierDismissible: canBeIgnored,
    builder: (context) => PopScope(
      canPop: canBeIgnored,
      child: !kIsWeb ? dialog : Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: webMaxWidth,
            maxHeight: webMaxHeight,
          ),
          child: dialog
        )
      )
    )
  );
}

void askRestartApp(BuildContext context) {
  actionsDialog(
    context,
    title: "general.askRestartApp.dialogTitle".tr(),
    content: "general.askRestartApp.dialogContent".tr(),
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
        style: TextButton.styleFrom(foregroundColor: Colors.blue[500]),
        child: Text("general.confirm".tr()),
        onPressed: () {
          Haptic().light();
          Phoenix.rebirth(context);
        },
      ),
    ]
  );
}