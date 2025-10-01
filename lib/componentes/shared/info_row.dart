import 'package:flutter/material.dart';

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 160,
    this.alignEnd = true,
    this.showColon = false,
    this.labelStyle,
    this.valueStyle,
    this.verticalPadding = 8,
  });

  final String label;
  final String value;
  final double labelWidth;
  final bool alignEnd;
  final bool showColon;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? '-' : value;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              showColon ? '$label:' : label,
              style:
                  labelStyle ??
                  textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style:
                  valueStyle ??
                  textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
