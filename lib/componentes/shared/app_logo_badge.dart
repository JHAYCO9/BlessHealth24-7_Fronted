import 'package:flutter/material.dart';

class AppLogoBadge extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry padding;

  const AppLogoBadge({
    super.key,
    this.height = 72,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: padding,
      child: Image.asset(
        'assets/images/Logo1.png',
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
