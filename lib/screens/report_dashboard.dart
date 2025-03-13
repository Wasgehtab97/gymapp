import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_services.dart';
import '../widgets/feedback_overview.dart';

class ReportDashboardScreen extends StatefulWidget {
  const ReportDashboardScreen({super.key});

  @override
  _ReportDashboardScreenState createState() => _ReportDashboardScreenState();
}

class _ReportDashboardScreenState extends State<ReportDashboardScreen> {
  final ApiService apiService = ApiService();

  List<dynamic> reportData = [];
  List<dynamic> devices = [];
  String startDate = '';
  String endDate = '';
  String selectedDevice = '';
  bool showFeedbackOverview = false;
  bool isLoading = false;
  final int lowUsageThreshold = 3;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    _fetchReportData();
  }

  Future<void> _fetchDevices() async {
    try {
      final fetchedDevices = await apiService.getDevices();
      setState(() {
        devices = fetchedDevices;
      });
    } catch (error) {
      debugPrint('Fehler beim Abrufen der Geräte: $error');
    }
  }

  Future<void> _fetchReportData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final data = await apiService.getReportingData(
        startDate: startDate.isNotEmpty ? startDate : null,
        endDate: endDate.isNotEmpty ? endDate : null,
        deviceId: selectedDevice.isNotEmpty ? selectedDevice : null,
      );
      setState(() {
        reportData = data;
      });
    } catch (error) {
      debugPrint('Fehler beim Abrufen der Nutzungshäufigkeit: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.red,
          width: 16,
        ),
      ],
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    List<BarChartGroupData> groups = [];
    for (int i = 0; i < reportData.length; i++) {
      double sessionCount =
          double.tryParse(reportData[i]['session_count'].toString()) ?? 0.0;
      groups.add(_makeGroupData(i, sessionCount));
    }
    return groups;
  }

  List<String> _getChartLabels() {
    return reportData.map((item) {
      final devId = item['device_id'];
      final found = devices.firstWhere((d) => d['id'] == devId, orElse: () => null);
      return found != null ? found['name'].toString() : 'Gerät $devId';
    }).toList();
  }

  // Nur eine Getter-Deklaration!
  List<dynamic> get devicesWithLowUsage {
    return reportData.where((item) {
      int count = int.tryParse(item['session_count'].toString()) ?? 0;
      return count < lowUsageThreshold;
    }).toList();
  }

  void _handleFeedbackRequest(dynamic deviceId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Feedback-Anfrage für Gerät $deviceId gesendet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartLabels = _getChartLabels();
    final barGroups = _buildBarGroups();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reporting-Dashboard: Nutzungshäufigkeit',
          style: TextStyle(color: Colors.red),
        ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter-UI: Flexible Datumseingabe
              Row(
                children: [
                  const Text("Startdatum: ", style: TextStyle(color: Colors.red)),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.red),
                      decoration: const InputDecoration(
                        hintText: 'YYYY-MM-DD',
                        hintStyle: TextStyle(color: Colors.redAccent),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          startDate = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text("Enddatum: ", style: TextStyle(color: Colors.red)),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.red),
                      decoration: const InputDecoration(
                        hintText: 'YYYY-MM-DD',
                        hintStyle: TextStyle(color: Colors.redAccent),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          endDate = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Geräteauswahl Dropdown
              Row(
                children: [
                  const Text("Gerät auswählen: ", style: TextStyle(color: Colors.red)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedDevice.isNotEmpty ? selectedDevice : null,
                    hint: const Text("Alle Geräte", style: TextStyle(color: Colors.red)),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text("Alle Geräte", style: TextStyle(color: Colors.red)),
                      ),
                      ...devices.map((device) {
                        return DropdownMenuItem<String>(
                          value: device['id'].toString(),
                          child: Text(device['name'].toString(), style: const TextStyle(color: Colors.red)),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedDevice = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _fetchReportData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    child: const Text("Filter anwenden", style: TextStyle(color: Colors.red, fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Balkendiagramm: X-Achsen-Beschriftungen gedreht
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AspectRatio(
                      aspectRatio: 1.5,
                      child: BarChart(
                        BarChartData(
                          barGroups: barGroups,
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  int index = value.toInt();
                                  if (index >= 0 && index < chartLabels.length) {
                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 4,
                                      child: Transform.rotate(
                                        angle: -pi / 4,
                                        child: Text(
                                          chartLabels[index],
                                          style: const TextStyle(fontSize: 10, color: Colors.red),
                                        ),
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
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10, color: Colors.red),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.red.withOpacity(0.3),
                                strokeWidth: 1,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
              // Detailübersicht als DataTable
              const Text(
                "Detailübersicht",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 16),
              DataTable(
                columns: const [
                  DataColumn(label: Text('Gerät', style: TextStyle(color: Colors.red))),
                  DataColumn(label: Text('Nutzungshäufigkeit', style: TextStyle(color: Colors.red))),
                ],
                rows: reportData.map<DataRow>((item) {
                  final devId = item['device_id'];
                  final found = devices.firstWhere((d) => d['id'] == devId, orElse: () => null);
                  final deviceName = found != null ? found['name'].toString() : 'Gerät $devId';
                  return DataRow(cells: [
                    DataCell(Text(deviceName, style: const TextStyle(color: Colors.red))),
                    DataCell(Text(item['session_count'].toString(), style: const TextStyle(color: Colors.red))),
                  ]);
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Feedback-Anfragen bei niedriger Nutzung
              if (devicesWithLowUsage.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Feedback-Anfragen",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: devicesWithLowUsage.map((item) {
                        final devId = item['device_id'];
                        final found = devices.firstWhere((d) => d['id'] == devId, orElse: () => null);
                        final deviceName = found != null ? found['name'].toString() : 'Gerät $devId';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "$deviceName hat nur ${item['session_count']} Trainingseinheiten.",
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _handleFeedbackRequest(devId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                child: const Text("Feedback anfordern", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // Feedback Übersicht ein-/ausblenden
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showFeedbackOverview = !showFeedbackOverview;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                child: Text(
                  showFeedbackOverview ? "Feedback Übersicht ausblenden" : "Feedback Übersicht anzeigen",
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
              if (showFeedbackOverview) const FeedbackOverview(),
            ],
          ),
        ),
      ),
    );
  }
}
