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
  late int deviceId;

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
    // deviceId wird als Route-Argument übergeben
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      deviceId = args;
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Ungültige Geräte-ID")));
      return;
    }
    if (userId != null) {
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await ApiService().getHistory(userId!, deviceId);
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

  // Formatiert ein Datum (String oder DateTime) im Format YYYY-MM-DD
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

  // Gruppiert die Trainingsdaten nach Datum
  Map<String, List<dynamic>> _groupHistoryByDate() {
    Map<String, List<dynamic>> grouped = {};
    for (var entry in historyData) {
      String dateFormatted = _formatLocalDate(entry['training_date']);
      if (!grouped.containsKey(dateFormatted)) {
        grouped[dateFormatted] = [];
      }
      grouped[dateFormatted]!.add(entry);
    }
    return grouped;
  }

  // Gibt die gruppierten Datumskeys sortiert zurück
  List<String> _getSortedDates(Map<String, List<dynamic>> grouped) {
    List<String> dates = grouped.keys.toList();
    dates.sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupHistoryByDate();
    final sortedDates = _getSortedDates(groupedData);

    // Erstellung der Chart-Daten: Für jedes Datum wird der gewichtete Durchschnitt (geschätztes 1RM) berechnet.
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
        title: Text('Trainingshistorie für Nutzer ${userId ?? 'unbekannt'}'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Leistungsverlauf',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Diagramm zur Visualisierung des Leistungsverlaufs
                  SizedBox(
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
                                  return Text(
                                    chartLabels[index],
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 10,
                            ),
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
                  const SizedBox(height: 24),
                  // Anzeige der gruppierten Trainingsdaten
                  if (groupedData.isNotEmpty)
                    Column(
                      children: sortedDates.map((date) {
                        List<dynamic> sessions = groupedData[date]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                date,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Satz')),
                                    DataColumn(label: Text('Kg')),
                                    DataColumn(label: Text('Wdh')),
                                  ],
                                  rows: sessions.map<DataRow>((entry) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(entry['sets'].toString())),
                                        DataCell(Text(entry['weight'].toString())),
                                        DataCell(Text(entry['reps'].toString())),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Text("Keine Trainingshistorie vorhanden."),
                ],
              ),
            ),
    );
  }
}
