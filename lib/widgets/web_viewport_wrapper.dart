import 'package:escive/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebViewportWrapper extends StatelessWidget {
  final Widget child;

  const WebViewportWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: webMaxWidth,
          maxHeight: webMaxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
        ),
      ),
    );
  }
}