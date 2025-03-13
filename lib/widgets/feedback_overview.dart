import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class FeedbackOverview extends StatefulWidget {
  const FeedbackOverview({Key? key}) : super(key: key);

  @override
  _FeedbackOverviewState createState() => _FeedbackOverviewState();
}

class _FeedbackOverviewState extends State<FeedbackOverview> {
  List<dynamic> feedbacks = [];
  List<dynamic> devices = [];
  String deviceFilter = '';
  String statusFilter = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    _fetchFeedbacks();
  }

  Future<void> _fetchDevices() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/api/devices'));
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['data'] != null) {
        setState(() {
          devices = result['data'];
        });
      } else {
        debugPrint(result['error']?.toString());
      }
    } catch (error) {
      debugPrint('Fehler beim Abrufen der Geräte: $error');
    }
  }

  Future<void> _fetchFeedbacks() async {
    setState(() {
      loading = true;
    });
    try {
      List<String> queryParams = [];
      if (deviceFilter.isNotEmpty) {
        queryParams.add('deviceId=${Uri.encodeComponent(deviceFilter)}');
      }
      if (statusFilter.isNotEmpty) {
        queryParams.add('status=${Uri.encodeComponent(statusFilter)}');
      }
      String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final response = await http.get(Uri.parse('$API_URL/api/feedback$queryString'));
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['data'] != null) {
        setState(() {
          feedbacks = result['data'];
        });
      } else {
        debugPrint(result['error']?.toString());
      }
    } catch (error) {
      debugPrint('Fehler beim Abrufen des Feedbacks: $error');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _updateFeedbackStatus(int feedbackId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$API_URL/api/feedback/$feedbackId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          feedbacks = feedbacks.map((fb) {
            if (fb['id'] == feedbackId) {
              fb['status'] = newStatus;
            }
            return fb;
          }).toList();
        });
      } else {
        debugPrint(result['error']?.toString());
      }
    } catch (error) {
      debugPrint('Fehler beim Aktualisieren des Feedback-Status: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Feedback Übersicht',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 16),
          // Filter-UI: Dropdowns für Gerät und Status
          Row(
            children: [
              const Text("Gerät auswählen: ", style: TextStyle(color: Colors.red)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: deviceFilter.isNotEmpty ? deviceFilter : null,
                hint: const Text("Alle Geräte", style: TextStyle(color: Colors.red)),
                items: [
                  const DropdownMenuItem(value: '', child: Text("Alle Geräte", style: TextStyle(color: Colors.red))),
                  ...devices.map<DropdownMenuItem<String>>((device) {
                    return DropdownMenuItem<String>(
                      value: device['id'].toString(),
                      child: Text(device['name'].toString(), style: const TextStyle(color: Colors.red)),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    deviceFilter = value ?? '';
                  });
                  _fetchFeedbacks();
                },
              ),
              const SizedBox(width: 16),
              const Text("Status: ", style: TextStyle(color: Colors.red)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: statusFilter.isNotEmpty ? statusFilter : null,
                hint: const Text("Alle", style: TextStyle(color: Colors.red)),
                items: const [
                  DropdownMenuItem(value: '', child: Text("Alle", style: TextStyle(color: Colors.red))),
                  DropdownMenuItem(value: 'neu', child: Text("Neu", style: TextStyle(color: Colors.red))),
                  DropdownMenuItem(value: 'in Bearbeitung', child: Text("In Bearbeitung", style: TextStyle(color: Colors.red))),
                  DropdownMenuItem(value: 'erledigt', child: Text("Erledigt", style: TextStyle(color: Colors.red))),
                ],
                onChanged: (value) {
                  setState(() {
                    statusFilter = value ?? '';
                  });
                  _fetchFeedbacks();
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _fetchFeedbacks,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text("Filter anwenden", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Anzeige der Feedbacks in einer DataTable
          loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID', style: TextStyle(color: Colors.red))),
                      DataColumn(label: Text('Gerät', style: TextStyle(color: Colors.red))),
                      DataColumn(label: Text('Feedback', style: TextStyle(color: Colors.red))),
                      DataColumn(label: Text('Datum', style: TextStyle(color: Colors.red))),
                      DataColumn(label: Text('Status', style: TextStyle(color: Colors.red))),
                      DataColumn(label: Text('Aktionen', style: TextStyle(color: Colors.red))),
                    ],
                    rows: feedbacks.map<DataRow>((fb) {
                      final deviceId = fb['device_id'];
                      final device = devices.firstWhere((d) => d['id'] == deviceId, orElse: () => null);
                      final deviceName = device != null ? device['name'].toString() : 'Gerät $deviceId';
                      final createdAt = DateTime.tryParse(fb['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
                      final formattedDate =
                          "${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}";
                      return DataRow(
                        cells: [
                          DataCell(Text(fb['id'].toString(), style: const TextStyle(color: Colors.red))),
                          DataCell(Text(deviceName, style: const TextStyle(color: Colors.red))),
                          DataCell(Text(fb['feedback_text'].toString(), style: const TextStyle(color: Colors.red))),
                          DataCell(Text(formattedDate, style: const TextStyle(color: Colors.red))),
                          DataCell(Text(fb['status'].toString(), style: const TextStyle(color: Colors.red))),
                          DataCell(
                            fb['status'] != 'erledigt'
                                ? ElevatedButton(
                                    onPressed: () => _updateFeedbackStatus(fb['id'], 'erledigt'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                                    child: const Text("Als erledigt markieren", style: TextStyle(color: Colors.red)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}
