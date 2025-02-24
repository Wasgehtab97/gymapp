// lib/widgets/feedback_form.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class FeedbackForm extends StatefulWidget {
  final int deviceId;
  final VoidCallback? onClose;
  final Function(Map<String, dynamic>)? onFeedbackSubmitted;

  const FeedbackForm({
    Key? key,
    required this.deviceId,
    this.onClose,
    this.onFeedbackSubmitted,
  }) : super(key: key);

  @override
  _FeedbackFormState createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _feedbackController = TextEditingController();
  String _error = '';
  String _success = '';

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final feedbackText = _feedbackController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (userId == null) {
      setState(() {
        _error = 'Benutzer nicht authentifiziert.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$API_URL/api/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'deviceId': widget.deviceId,
          'feedback_text': feedbackText,
        }),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _success = 'Feedback erfolgreich gesendet.';
          _error = '';
          _feedbackController.clear();
        });
        if (widget.onFeedbackSubmitted != null) {
          widget.onFeedbackSubmitted!(result['data']);
        }
        if (widget.onClose != null) {
          widget.onClose!();
        }
      } else {
        setState(() {
          _error = result['error'] ?? 'Fehler beim Absenden des Feedbacks.';
        });
      }
    } catch (err) {
      setState(() {
        _error = 'Serverfehler beim Absenden des Feedbacks.';
      });
      debugPrint('Fehler beim Absenden des Feedbacks: $err');
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feedback geben',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _error,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_success.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _success,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Bitte geben Sie Ihr Feedback ein...',
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().length < 10) {
                  return 'Bitte geben Sie ein Feedback mit mindestens 10 Zeichen ein.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _handleSubmit,
                  child: const Text('Absenden'),
                ),
                if (widget.onClose != null) const SizedBox(width: 8),
                if (widget.onClose != null)
                  ElevatedButton(
                    onPressed: widget.onClose,
                    child: const Text('Abbrechen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
