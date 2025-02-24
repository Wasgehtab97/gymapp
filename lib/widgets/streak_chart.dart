// lib/widgets/streak_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StreakChart extends StatelessWidget {
  final int streak;

  const StreakChart({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    // Erzeuge Labels wie "Tag 1", "Tag 2", ... , "Tag streak"
    final List<String> labels =
        List.generate(streak, (index) => 'Tag ${index + 1}');
    // Erzeuge Datenpunkte: x = Index, y = (index+1)
    final List<FlSpot> spots = List.generate(
      streak,
      (index) => FlSpot(index.toDouble(), (index + 1).toDouble()),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Text(
            'Streak Visualisierung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: streak > 0 ? (streak - 1).toDouble() : 0,
                minY: 0,
                maxY: streak.toDouble(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    barWidth: 2,
                    color: Colors.teal,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              labels[index],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
