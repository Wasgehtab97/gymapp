import 'package:flutter/material.dart';

class ExpBadge extends StatelessWidget {
  final int expProgress; // Fortschritt in der aktuellen Division (0–999)
  final int divisionIndex; // 0 = Bronze 4, 1 = Bronze 3, 2 = Bronze 2, 3 = Bronze 1, 4 = Silver 4, etc.
  final double size;

  const ExpBadge({
    Key? key,
    required this.expProgress,
    required this.divisionIndex,
    this.size = 60,
  }) : super(key: key);

  static const List<String> divisionNames = [
    'Bronze 4',
    'Bronze 3',
    'Bronze 2',
    'Bronze 1',
    'Silver 4',
    'Silver 3',
    'Silver 2',
    'Silver 1',
    'Gold 4',
    'Gold 3',
    'Gold 2',
    'Gold 1',
  ];

  // Für jede Division wird anhand des Modulo-4 die römische Zahl ausgewählt:
  static const List<String> romanNumerals = ['IV', 'III', 'II', 'I'];

  // Bestimme die Farbe je Division:
  Color _getDivisionColor() {
    if (divisionIndex < 4) {
      return const Color(0xFFCD7F32); // Bronze
    } else if (divisionIndex < 8) {
      return const Color(0xFFC0C0C0); // Silver
    } else if (divisionIndex < 12) {
      return const Color(0xFFFFD700); // Gold
    } else {
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final division = (divisionIndex < divisionNames.length) ? divisionNames[divisionIndex] : 'Unbekannt';
    final roman = romanNumerals[divisionIndex % 4];
    final divisionColor = _getDivisionColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
        color: divisionColor.withOpacity(0.2), // Leicht eingefärbter Hintergrund
      ),
      child: Center(
        child: Text(
          roman,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: divisionColor,
          ),
        ),
      ),
    );
  }
}
