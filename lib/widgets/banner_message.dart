import 'package:flutter/material.dart';

Widget bannerMessage(BuildContext context, { Widget content = const SizedBox(), MaterialColor materialColor = Colors.blue }) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: materialColor[50],
      boxShadow: [
        BoxShadow(
          color: materialColor.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
      border: Border.all(color: materialColor[200]!, width: 1),
    ),
    child: content
  );
}