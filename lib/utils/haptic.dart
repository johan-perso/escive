import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

bool supported = Platform.isIOS || Platform.isAndroid;

class Haptic {
  void light() {
    if(supported) HapticFeedback.lightImpact();
  }

  void click() { // even lighter than light
    if(supported) HapticFeedback.selectionClick();
  }

  void heavy() {
    if(supported) Haptics.vibrate(HapticsType.heavy);
  }

  void success() {
    if(supported) Haptics.vibrate(HapticsType.success);
  }

  void warning() {
    if(supported) Haptics.vibrate(HapticsType.warning);
  }

  void error() {
    if(supported) Haptics.vibrate(HapticsType.error);
  }
}