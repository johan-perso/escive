import 'package:escive/main.dart';
import 'package:escive/utils/haptic.dart';
import 'package:escive/utils/show_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' as localization;

void attachLogarteButton(BuildContext context) {
  Haptic().light();
  showSnackBar(context, "general.debugWarn".tr(), icon: "warning");
  logarte.attach(context: context, visible: true);
}