import 'package:flutter/material.dart';

class StreakBadge extends StatelessWidget {
  final int streak;
  final double size;

  const StreakBadge({Key? key, required this.streak, this.size = 60}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Verwende zentrales Theme für Farben und Textstile:
    final borderColor = Theme.of(context).dividerColor;
    final iconColor = Theme.of(context).colorScheme.secondary;
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: size * 0.33,
      fontWeight: FontWeight.bold,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.local_fire_department,
            size: size * 0.8,
            color: iconColor,
          ),
          Text(
            streak.toString(),
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
