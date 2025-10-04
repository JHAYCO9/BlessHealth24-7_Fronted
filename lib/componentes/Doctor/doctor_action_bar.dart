import 'package:flutter/material.dart';

import 'doctor_helpers.dart';

class DoctorActionBar extends StatelessWidget {
  final List<DoctorAction> actions;
  final EdgeInsetsGeometry padding;

  const DoctorActionBar({
    super.key,
    required this.actions,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: actions
            .map(
              (action) => ElevatedButton.icon(
                onPressed: action.onPressed,
                style: buildDoctorQuickActionStyle(),
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

class DoctorAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const DoctorAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}
