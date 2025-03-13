// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ApiService {
  final String baseUrl = API_URL;

  // Geräte abrufen
  Future<List<dynamic>> getDevices() async {
    final response = await http.get(Uri.parse('$baseUrl/api/devices'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'];
    } else {
      throw Exception('Failed to load devices: ${response.statusCode}');
    }
  }

  // Trainingshistorie für einen Nutzer abrufen
  // Optional: Falls 'exercise' gesetzt ist, wird danach gefiltert, ansonsten nach 'deviceId'.
  Future<List<dynamic>> getHistory(int userId, {int? deviceId, String? exercise}) async {
    String url = '$baseUrl/api/history/$userId';
    List<String> queryParams = [];
    if (exercise != null && exercise.isNotEmpty) {
      queryParams.add("exercise=${Uri.encodeComponent(exercise)}");
    } else if (deviceId != null) {
      queryParams.add("deviceId=$deviceId");
    }
    if (queryParams.isNotEmpty) {
      url += '?' + queryParams.join('&');
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'];
    } else {
      throw Exception('Failed to load history: ${response.statusCode}');
    }
  }

  // Gerätedaten aktualisieren (nur Admin, Auth-geschützt)
  Future<Map<String, dynamic>> updateDevice(int deviceId, String name, String exerciseMode) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final response = await http.put(
      Uri.parse('$baseUrl/api/devices/$deviceId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'exercise_mode': exerciseMode,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'];
    } else {
      throw Exception('Failed to update device: ${response.statusCode}');
    }
  }

  // Benutzerregistrierung
  Future<Map<String, dynamic>> registerUser(String name, String email, String password, String membershipNumber) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'membershipNumber': membershipNumber,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Registration failed: ${response.statusCode}');
    }
  }

  // Benutzer-Login inkl. EXP-Daten (exp_progress und division_index)
  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      if (result.containsKey('exp_progress')) {
        await prefs.setInt('exp_progress', result['exp_progress']);
      }
      if (result.containsKey('division_index')) {
        await prefs.setInt('division_index', result['division_index']);
      }
      return result;
    } else {
      throw Exception('Login failed: ${response.statusCode}');
    }
  }

  // Trainingsdaten posten – überträgt auch den Übungsnamen, falls vorhanden.
  // Wir werfen den Response-Body als Exception, falls ein Fehler auftritt.
  Future<void> postTrainingData(Map<String, dynamic> trainingData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/training'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(trainingData),
    );
    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  // Reporting-Daten (Nutzungshäufigkeit) abrufen
  Future<List<dynamic>> getReportingData({String? startDate, String? endDate, String? deviceId}) async {
    List<String> queryParams = [];
    if (startDate != null && endDate != null) {
      queryParams.add("startDate=${Uri.encodeComponent(startDate)}");
      queryParams.add("endDate=${Uri.encodeComponent(endDate)}");
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      queryParams.add("deviceId=${Uri.encodeComponent(deviceId)}");
    }
    String queryString = queryParams.isNotEmpty ? "?${queryParams.join("&")}" : "";
    final response = await http.get(Uri.parse('$baseUrl/api/reporting/usage$queryString'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'];
    } else {
      throw Exception('Failed to load reporting data: ${response.statusCode}');
    }
  }

  // Allgemeine Methode zum Abrufen von Daten (z.B. für den Streak)
  Future<Map<String, dynamic>> getDataFromUrl(String endpoint) async {
    final response = await http.get(Uri.parse('$baseUrl$endpoint'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get data from $endpoint: ${response.statusCode}');
    }
  }

  // User-Daten abrufen (inkl. EXP-Daten)
  Future<Map<String, dynamic>> getUserData(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/user/$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get user data: ${response.statusCode}');
    }
  }

  // -------------------------
  // Trainingspläne
  // -------------------------

  Future<Map<String, dynamic>> createTrainingPlan(int userId, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/training-plans'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'name': name}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create training plan: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getTrainingPlans(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/training-plans/$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'];
    } else {
      throw Exception('Failed to get training plans: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateTrainingPlan(int planId, List<Map<String, dynamic>> exercises) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/training-plans/$planId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'exercises': exercises}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update training plan: ${response.statusCode}');
    }
  }

  Future<void> deleteTrainingPlan(int planId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/training-plans/$planId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete training plan: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> startTrainingPlan(int planId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/training-plans/$planId/start'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to start training plan: ${response.statusCode}');
    }
  }
}
