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

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    try {
      final data = await ApiService().getDevices();
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

  @override
  Widget build(BuildContext context) {
    final filteredDevices = devices.where((device) {
      final deviceName = device['name'].toString().toLowerCase();
      return deviceName.contains(filterQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Geräteübersicht'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Suchfeld
            Row(
              children: [
                const Text(
                  'Gerät suchen:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'z. B. Benchpress',
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
            // Ladeanzeige oder Liste der Geräte
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (filteredDevices.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: filteredDevices.length,
                  itemBuilder: (context, index) {
                    final device = filteredDevices[index];
                    debugPrint("Gerät ausgewählt: ${device['id']} (Type: ${device['id'].runtimeType})");
                    return ListTile(
                      title: Text(device['name']),
                      onTap: () {
                        // Navigiere zum Dashboard und übergebe die Geräte-ID als Argument
                        Navigator.pushNamed(
                          context,
                          '/dashboard',
                          arguments: device['id'],
                        );
                      },
                    );
                  },
                ),
              )
            else
              const Text('Keine Geräte gefunden.'),
          ],
        ),
      ),
    );
  }
}
