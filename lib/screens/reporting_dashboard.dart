// lib/screens/report_dashboard.dart
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

  // Erzeugt eine Balkengruppe für das Diagramm
  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y, color: Colors.teal, width: 16),
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

  // Erzeugt die x-Achsen-Beschriftungen basierend auf den Gerätenamen
  List<String> _getChartLabels() {
    return reportData.map((item) {
      final deviceId = item['device_id'];
      final found = devices.firstWhere((d) => d['id'] == deviceId, orElse: () => null);
      return found != null ? found['name'].toString() : 'Gerät $deviceId';
    }).toList();
  }

  final int lowUsageThreshold = 3;
  List<dynamic> get devicesWithLowUsage {
    return reportData.where((item) {
      int count = int.tryParse(item['session_count'].toString()) ?? 0;
      return count < lowUsageThreshold;
    }).toList();
  }

  void _handleFeedbackRequest(dynamic deviceId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Feedback-Anfrage für Gerät $deviceId gesendet.'))
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartLabels = _getChartLabels();
    final barGroups = _buildBarGroups();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporting-Dashboard: Nutzungshäufigkeit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter-UI
            Row(
              children: [
                const Text("Startdatum: "),
                SizedBox(
                  width: 150,
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
                    onChanged: (value) {
                      setState(() {
                        startDate = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Text("Enddatum: "),
                SizedBox(
                  width: 150,
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
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
            Row(
              children: [
                const Text("Gerät auswählen: "),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedDevice.isNotEmpty ? selectedDevice : null,
                  hint: const Text("Alle Geräte"),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text("Alle Geräte"),
                    ),
                    ...devices.map((device) {
                      return DropdownMenuItem<String>(
                        value: device['id'].toString(),
                        child: Text(device['name'].toString()),
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
                  child: const Text("Filter anwenden"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Balkendiagramm zur Darstellung der Nutzungshäufigkeit
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
                                    child: Text(
                                      chartLabels[index],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true, interval: 1),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: true),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
            const Text(
              "Detailübersicht",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Detailübersicht als DataTable
            DataTable(
              columns: const [
                DataColumn(label: Text('Gerät')),
                DataColumn(label: Text('Nutzungshäufigkeit')),
              ],
              rows: reportData.map<DataRow>((item) {
                final deviceId = item['device_id'];
                final found = devices.firstWhere((d) => d['id'] == deviceId, orElse: () => null);
                final deviceName = found != null ? found['name'].toString() : 'Gerät $deviceId';
                return DataRow(cells: [
                  DataCell(Text(deviceName)),
                  DataCell(Text(item['session_count'].toString())),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: devicesWithLowUsage.map((item) {
                      final deviceId = item['device_id'];
                      final found = devices.firstWhere((d) => d['id'] == deviceId, orElse: () => null);
                      final deviceName = found != null ? found['name'].toString() : 'Gerät $deviceId';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text("$deviceName hat nur ${item['session_count']} Trainingseinheiten."),
                            ),
                            ElevatedButton(
                              onPressed: () => _handleFeedbackRequest(deviceId),
                              child: const Text("Feedback anfordern"),
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
              child: Text(showFeedbackOverview
                  ? "Feedback Übersicht ausblenden"
                  : "Feedback Übersicht anzeigen"),
            ),
            if (showFeedbackOverview) const FeedbackOverview(),
          ],
        ),
      ),
    );
  }
}
