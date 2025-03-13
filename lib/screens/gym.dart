// lib/screens/gym.dart
import 'package:flutter/material.dart';
import '../services/api_services.dart';

class GymScreen extends StatefulWidget {
  const GymScreen({Key? key}) : super(key: key);

  @override
  _GymScreenState createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<dynamic> devices = [];
  String filterQuery = "";
  bool isLoading = true;
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    try {
      final data = await apiService.getDevices();
      if (!mounted) return;
      setState(() {
        devices = data;
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

  // Zeigt eine Auswahl der drei Grundübungen an
  void _showExerciseSelection(dynamic device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Wähle eine Übung",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.red),
                title: const Text("Bankdrücken", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/dashboard',
                    arguments: {
                      'deviceId': device['id'],
                      'exercise': 'Bankdrücken',
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.red),
                title: const Text("Kniebeugen", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/dashboard',
                    arguments: {
                      'deviceId': device['id'],
                      'exercise': 'Kniebeugen',
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.red),
                title: const Text("Kreuzheben", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/dashboard',
                    arguments: {
                      'deviceId': device['id'],
                      'exercise': 'Kreuzheben',
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = devices.where((device) {
      final deviceName = device['name'].toString().toLowerCase();
      return deviceName.contains(filterQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gym Geräteübersicht',
          style: TextStyle(color: Colors.red),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A), Color(0xFF333333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Gerät suchen...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.red.shade300),
                    ),
                    onChanged: (value) {
                      setState(() {
                        filterQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredDevices.isEmpty
                          ? const Center(
                              child: Text(
                              'Keine Geräte gefunden.',
                              style: TextStyle(color: Colors.white),
                            ))
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 3 / 2,
                              ),
                              itemCount: filteredDevices.length,
                              itemBuilder: (context, index) {
                                final device = filteredDevices[index];
                                return GestureDetector(
                                  onTap: () {
                                    // Prüfe den exercise_mode
                                    if (device['exercise_mode'] == 'multiple') {
                                      _showExerciseSelection(device);
                                    } else {
                                      Navigator.pushNamed(
                                        context,
                                        '/dashboard',
                                        arguments: {'deviceId': device['id']},
                                      );
                                    }
                                  },
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFEBEE), Color(0xFFC62828)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.fitness_center,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            child: Text(
                                              device['name'],
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 50,
        color: Colors.black,
      ),
    );
  }
}
