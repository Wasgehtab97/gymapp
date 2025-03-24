import 'package:flutter/material.dart';
import 'calendar.dart'; // Unser optimierter Kalender

class FullScreenCalendar extends StatelessWidget {
  final List<String> trainingDates;

  const FullScreenCalendar({Key? key, required this.trainingDates})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kalender',
          style: theme.appBarTheme.titleTextStyle,
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Calendar(
            trainingDates: trainingDates,
            cellSize: 16.0,
            cellSpacing: 3.0,
          ),
        ),
      ),
    );
  }
}
