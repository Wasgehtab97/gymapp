// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../widgets/device_update_form.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> devices = [];
  String filterQuery = "";
  Map<String, dynamic>? editingDevice;
  bool isLoading = true;
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    try {
      final fetchedDevices = await apiService.getDevices();
      // Optionale Sortierung – sortiere nach 'order' oder ID
      fetchedDevices.sort((a, b) {
        var orderA = a['order'] ?? a['id'];
        var orderB = b['order'] ?? b['id'];
        return orderA.compareTo(orderB);
      });
      if (!mounted) return;
      setState(() {
        devices = fetchedDevices;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint('Fehler beim Abrufen der Geräte: $error');
    }
  }

  void _handleDeviceUpdate(Map<String, dynamic> updatedDevice) {
    setState(() {
      devices = devices.map((device) {
        return device['id'] == updatedDevice['id'] ? updatedDevice : device;
      }).toList();
      editingDevice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filtere die Geräte anhand des Suchbegriffs (unabhängig von Groß-/Kleinschreibung)
    final filteredDevices = devices.where((device) {
      final name = device['name'].toString().toLowerCase();
      return name.contains(filterQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Dashboard', style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Geräteübersicht',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      // Filter-Input
                      Row(
                        children: [
                          const Text(
                            'Gerät suchen:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: const TextStyle(color: Colors.red),
                              decoration: const InputDecoration(
                                hintText: 'z. B. Benchpress',
                                hintStyle: TextStyle(color: Colors.redAccent),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  filterQuery = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Anzeige der Geräte
                      if (devices.isEmpty)
                        const Text("Keine Geräte verfügbar.", style: TextStyle(color: Colors.red))
                      else if (filteredDevices.isEmpty)
                        Text("Keine Geräte gefunden, die \"$filterQuery\" enthalten.", style: const TextStyle(color: Colors.red))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredDevices.length,
                          itemBuilder: (context, index) {
                            final device = filteredDevices[index];
                            final exerciseMode = device['exercise_mode'] == 'single'
                                ? 'Einzelübung'
                                : 'Mehrfachübung';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                title: Text(
                                  '${device['name']} ($exerciseMode)',
                                  style: const TextStyle(color: Colors.red),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      editingDevice = device;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                                  child: const Text('Bearbeiten', style: TextStyle(color: Colors.red)),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      // Bearbeitungsbereich für ein ausgewähltes Gerät
                      if (editingDevice != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bearbeite: ${editingDevice!['name']}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            DeviceUpdateForm(
                              deviceId: editingDevice!['id'],
                              currentName: editingDevice!['name'],
                              onUpdated: _handleDeviceUpdate,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  editingDevice = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                              child: const Text('Schließen', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
