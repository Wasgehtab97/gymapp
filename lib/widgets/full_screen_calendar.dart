import 'package:flutter/material.dart';
import 'calendar.dart';
import '../screens/training_details_screen.dart';

class FullScreenCalendar extends StatelessWidget {
  final List<String> trainingDates;

  const FullScreenCalendar({Key? key, required this.trainingDates}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Kalender', style: theme.appBarTheme.titleTextStyle),
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
            // Beim Tippen auf einen Tag:
            onDayTap: (DateTime day) {
              String formatted = "${day.year.toString().padLeft(4, '0')}-"
                  "${day.month.toString().padLeft(2, '0')}-"
                  "${day.day.toString().padLeft(2, '0')}";
              if (trainingDates.contains(formatted)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainingDetailsScreen(selectedDate: formatted),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
