import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../widgets/device_update_form.dart';
import '../widgets/device_create_form.dart';

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
      // Sortiere nach 'order' oder ID
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

  void _handleDeviceCreate(Map<String, dynamic> newDevice) {
    setState(() {
      devices.add(newDevice);
    });
  }

  void _showCreateDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return DeviceCreateForm(onCreated: _handleDeviceCreate);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = devices.where((device) {
      final name = device['name'].toString().toLowerCase();
      return name.contains(filterQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin-Dashboard',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          // Den Gradient kannst du in Zukunft auch zentral definieren
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
                      Text(
                        'Geräteübersicht',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Filter-Input
                      Row(
                        children: [
                          Text(
                            'Gerät suchen:',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: Theme.of(context).textTheme.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'z. B. Benchpress',
                                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                                border: Theme.of(context).inputDecorationTheme.border,
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
                      if (devices.isEmpty)
                        Text(
                          "Keine Geräte verfügbar.",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        )
                      else if (filteredDevices.isEmpty)
                        Text(
                          "Keine Geräte gefunden, die \"$filterQuery\" enthalten.",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        )
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
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      editingDevice = device;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                  ),
                                  child: Text(
                                    'Bearbeiten',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      if (editingDevice != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bearbeite: ${editingDevice!['name']}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                              ),
                              child: Text(
                                'Schließen',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDeviceDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }
}
