import 'package:flutter/material.dart';

class StreakBadge extends StatelessWidget {
  final int streak;
  final double size;

  const StreakBadge({Key? key, required this.streak, this.size = 60}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.local_fire_department,
            size: size * 0.8,
            color: Colors.deepOrange,
          ),
          Text(
            streak.toString(),
            style: TextStyle(
              fontSize: size * 0.33,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
