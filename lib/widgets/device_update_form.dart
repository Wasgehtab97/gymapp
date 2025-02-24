// lib/widgets/device_update_form.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class DeviceUpdateForm extends StatefulWidget {
  final int deviceId;
  final String currentName;
  final Function(Map<String, dynamic>)? onUpdated;

  const DeviceUpdateForm({
    Key? key,
    required this.deviceId,
    required this.currentName,
    this.onUpdated,
  }) : super(key: key);

  @override
  _DeviceUpdateFormState createState() => _DeviceUpdateFormState();
}

class _DeviceUpdateFormState extends State<DeviceUpdateForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    final newName = _nameController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.put(
        Uri.parse('$API_URL/api/devices/${widget.deviceId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': newName}),
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _message = 'Gerätename erfolgreich aktualisiert!';
        });
        if (widget.onUpdated != null) {
          widget.onUpdated!(result['data']);
        }
      } else {
        setState(() {
          _message = result['error'] ?? 'Fehler beim Aktualisieren.';
        });
      }
    } catch (error) {
      setState(() {
        _message = 'Fehler beim Aktualisieren.';
      });
      debugPrint('Update-Fehler: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Neuer Gerätename:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Gib einen neuen Namen ein',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitte einen Namen eingeben.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _handleUpdate,
            child: const Text('Aktualisieren'),
          ),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_message),
            ),
        ],
      ),
    );
  }
}
