import 'package:flutter/material.dart';

class Calendar extends StatelessWidget {
  final List<String> trainingDates;
  final double cellSize;
  final int rows;
  final double cellSpacing;

  const Calendar({
    Key? key,
    required this.trainingDates,
    this.cellSize = 12.0,
    this.rows = 7,
    this.cellSpacing = 2.0,
  }) : super(key: key);

  /// Formatiert ein Datum als "YYYY-MM-DD".
  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  }

  /// Erzeugt eine Liste aller Tage des aktuellen Jahres.
  List<DateTime> _getAllDaysOfYear() {
    final currentYear = DateTime.now().year;
    final firstDay = DateTime(currentYear, 1, 1);
    final lastDay = DateTime(currentYear, 12, 31);
    final totalDays = lastDay.difference(firstDay).inDays + 1;
    return List.generate(totalDays, (index) => firstDay.add(Duration(days: index)));
  }

  /// Prüft, ob an einem Datum trainiert wurde.
  bool _isTrainingDay(DateTime date) {
    return trainingDates.contains(_formatDate(date));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDays = _getAllDaysOfYear();
    // Offset: Leere Zellen, damit der 1. Januar in die richtige Woche fällt.
    final int firstWeekdayOffset = DateTime(allDays.first.year, 1, 1).weekday - 1;
    final List<DateTime?> cells = List<DateTime?>.filled(firstWeekdayOffset, null, growable: true)
      ..addAll(allDays);
    // Am Ende auffüllen, sodass die Gesamtanzahl ein Vielfaches von 7 ist.
    final int remainder = cells.length % rows;
    if (remainder != 0) {
      cells.addAll(List<DateTime?>.filled(rows - remainder, null));
    }
    // Anzahl der Spalten (Wochen)
    final int columns = (cells.length / rows).ceil();
    // Gesamtbreite des Kalenders
    final double totalWidth = columns * (cellSize + cellSpacing);

    // Header: 12 gleich breite Zellen für die Monatskürzel.
    final double headerCellWidth = totalWidth / 12;
    final List<String> monthLabels = ["Ja", "Fe", "M", "A", "Ma", "Jun", "Jul", "Au", "S", "O", "N", "D"];
    final List<Widget> headerCells = List.generate(12, (index) {
      return SizedBox(
        width: headerCellWidth,
        child: Center(
          child: Text(
            monthLabels[index],
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 8, color: Colors.white),
          ),
        ),
      );
    });

    // Erstelle den Kalender-Grid als Table.
    final List<TableRow> tableRows = [];
    for (int r = 0; r < rows; r++) {
      final List<Widget> rowCells = [];
      for (int c = 0; c < columns; c++) {
        final int index = c * rows + r;
        if (index < cells.length && cells[index] != null) {
          final DateTime day = cells[index]!;
          final DateTime today = DateTime.now();
          final bool isTraining = _isTrainingDay(day);
          final bool isToday = day.year == today.year && day.month == today.month && day.day == today.day;
          rowCells.add(Padding(
            padding: EdgeInsets.all(cellSpacing / 2),
            child: SizedBox(
              width: cellSize,
              height: cellSize,
              child: Container(
                decoration: BoxDecoration(
                  color: isTraining ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    width: isToday ? 1.5 : 1.0,
                    color: isToday ? theme.colorScheme.secondary : Colors.white,
                  ),
                ),
              ),
            ),
          ));
        } else {
          rowCells.add(Padding(
            padding: EdgeInsets.all(cellSpacing / 2),
            child: SizedBox(width: cellSize, height: cellSize),
          ));
        }
      }
      tableRows.add(TableRow(children: rowCells));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: totalWidth,
            color: theme.scaffoldBackgroundColor,
            padding: EdgeInsets.all(cellSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: headerCells),
                const SizedBox(height: 4),
                Table(
                  defaultColumnWidth: FixedColumnWidth(cellSize + cellSpacing),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: tableRows,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
