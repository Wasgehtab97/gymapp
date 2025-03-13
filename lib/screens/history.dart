// lib/screens/history.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> historyData = [];
  bool isLoading = true;
  int? userId;
  int? deviceId;
  String? exercise;

  @override
  void initState() {
    super.initState();
    _loadUserAndFetchHistory();
  }

  Future<void> _loadUserAndFetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('userId');
    });
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      // Hier erwarten wir deviceId und optional exercise
      deviceId = args['deviceId'];
      if (args.containsKey('exercise')) {
        exercise = args['exercise'];
      }
    } else if (args is int) {
      deviceId = args;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ungültige Geräte-ID")),
      );
      return;
    }
    if (userId != null) {
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    try {
      // Rufe die Trainingshistorie ab – falls ein Übungsname gesetzt ist, wird dieser genutzt, sonst die deviceId
      final data = await ApiService().getHistory(
        userId!,
        deviceId: deviceId,
        exercise: exercise,
      );
      setState(() {
        historyData = data;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Fehler beim Abrufen der Trainingshistorie: $error");
    }
  }

  String _formatLocalDate(dynamic dateInput) {
    DateTime d;
    if (dateInput is String) {
      d = DateTime.parse(dateInput);
    } else if (dateInput is DateTime) {
      d = dateInput;
    } else {
      d = DateTime.now();
    }
    String pad(int n) => n.toString().padLeft(2, '0');
    return "${d.year}-${pad(d.month)}-${pad(d.day)}";
  }

  Map<String, List<dynamic>> _groupHistoryByDate() {
    Map<String, List<dynamic>> grouped = {};
    for (var entry in historyData) {
      String dateFormatted = _formatLocalDate(entry['training_date']);
      grouped.putIfAbsent(dateFormatted, () => []).add(entry);
    }
    return grouped;
  }

  List<String> _getSortedDates(Map<String, List<dynamic>> grouped) {
    List<String> dates = grouped.keys.toList();
    dates.sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupHistoryByDate();
    final sortedDates = _getSortedDates(groupedData);

    // Diagramm-Daten: Berechne für jedes Datum einen gewichteten Durchschnitt (1RM-Schätzwert)
    List<String> chartLabels = sortedDates;
    List<double> chartDataPoints = sortedDates.map((date) {
      final sessions = groupedData[date]!;
      double totalWeighted1RM = 0.0;
      int totalReps = 0;
      for (var entry in sessions) {
        double weight = double.tryParse(entry['weight'].toString()) ?? 0.0;
        int reps = int.tryParse(entry['reps'].toString()) ?? 0;
        totalWeighted1RM += weight * (1 + reps / 30) * reps;
        totalReps += reps;
      }
      double weightedAvg1RM = totalReps > 0 ? totalWeighted1RM / totalReps : 0.0;
      return weightedAvg1RM;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainingshistorie', style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A), Color(0xFF333333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Leistungsverlauf',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 300,
                          child: LineChart(
                            LineChartData(
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      int index = value.toInt();
                                      if (index >= 0 && index < chartLabels.length) {
                                        return SideTitleWidget(
                                          meta: meta,
                                          space: 4,
                                          child: Text(
                                            chartLabels[index],
                                            style: const TextStyle(fontSize: 10, color: Colors.red),
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
                                    interval: 10,
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 10, color: Colors.red),
                                    ),
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    chartDataPoints.length,
                                    (index) => FlSpot(index.toDouble(), chartDataPoints[index]),
                                  ),
                                  isCurved: true,
                                  color: Colors.teal,
                                  barWidth: 3,
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (groupedData.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedDates.map((date) {
                          List<dynamic> sessions = groupedData[date]!;
                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Satz', style: TextStyle(color: Colors.red))),
                                        DataColumn(label: Text('Kg', style: TextStyle(color: Colors.red))),
                                        DataColumn(label: Text('Wdh', style: TextStyle(color: Colors.red))),
                                      ],
                                      rows: sessions.map<DataRow>((entry) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(entry['sets'].toString(), style: const TextStyle(color: Colors.red))),
                                            DataCell(Text(entry['weight'].toString(), style: const TextStyle(color: Colors.red))),
                                            DataCell(Text(entry['reps'].toString(), style: const TextStyle(color: Colors.red))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      const Center(child: Text("Keine Trainingshistorie vorhanden.", style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
      ),
    );
  }
}
