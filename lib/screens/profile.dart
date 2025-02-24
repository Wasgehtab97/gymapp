// lib/screens/profile.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import '../widgets/registration_form.dart';
import '../widgets/login_form.dart';
import '../widgets/streak_chart.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String storedUsername = "BeispielNutzer";
  String? token;
  int? userId;
  bool showCalendar = false;
  List<String> trainingDates = [];
  bool loadingDates = true;
  int streak = 0;
  bool loadingStreak = true;

  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      storedUsername = prefs.getString('username') ?? "BeispielNutzer";
      token = prefs.getString('token');
      userId = prefs.getInt('userId');
    });
    if (userId != null) {
      _fetchStreak();
      _fetchTrainingDates();
    }
  }

  // Formatiert ein Datum im Format YYYY-MM-DD
  String getLocalDateString(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  }

  Future<void> _fetchStreak() async {
    try {
      final response = await apiService.getDataFromUrl('/api/streak/${userId!}');
      setState(() {
        streak = response['data']['current_streak'] ?? 0;
      });
    } catch (error) {
      debugPrint("Fehler beim Abrufen des Streaks: $error");
    } finally {
      setState(() {
        loadingStreak = false;
      });
    }
  }

  Future<void> _fetchTrainingDates() async {
    try {
      final response = await apiService.getDataFromUrl('/api/history/${userId!}');
      if (response['data'] != null) {
        final dates = response['data']
            .map<String>((entry) {
              DateTime d = DateTime.parse(entry['training_date']);
              return getLocalDateString(d);
            })
            .toSet()
            .toList();
        setState(() {
          trainingDates = dates;
        });
      }
    } catch (error) {
      debugPrint("Fehler beim Abrufen der Trainingsdaten: $error");
    } finally {
      setState(() {
        loadingDates = false;
      });
    }
  }

  // Logout: Löscht die SharedPreferences und navigiert zur Startseite.
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  // Prüft, ob das angegebene Datum als Trainingstag markiert ist.
  bool _isTrainingDay(DateTime date) {
    final formatted = getLocalDateString(date);
    return trainingDates.contains(formatted);
  }

  @override
  Widget build(BuildContext context) {
    // Falls kein Token vorhanden ist, zeige Login-/Registrierungsformulare an.
    if (token == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Login / Registrierung")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: const [
              RegistrationForm(),
              SizedBox(height: 20),
              LoginForm(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Nutzername, der den Kalender umschaltet
            Row(
              children: [
                const Text(
                  "Nutzername: ",
                  style: TextStyle(fontSize: 18),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showCalendar = !showCalendar;
                    });
                  },
                  child: Text(
                    storedUsername,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Anzeige des aktuellen Streaks und des zugehörigen Diagramms
            loadingStreak
                ? const Text("Lade Streak...")
                : Column(
                    children: [
                      Text("Aktueller Streak: $streak Tage",
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      StreakChart(streak: streak),
                    ],
                  ),
            const SizedBox(height: 16),
            // Button zum Logout
            ElevatedButton(
              onPressed: _handleLogout,
              child: const Text("Abmelden"),
            ),
            const SizedBox(height: 16),
            // Button, um zur Trainingsplan-Seite zu navigieren
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/trainingsplan');
              },
              child: const Text("Trainingsplan"),
            ),
            const SizedBox(height: 16),
            // Kalenderanzeige
            if (showCalendar)
              Column(
                children: [
                  const Text(
                    "Trainings-Tage",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  loadingDates
                      ? const Text("Lade Trainingsdaten...")
                      : TableCalendar(
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2100),
                          focusedDay: DateTime.now(),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, date, _) {
                              if (_isTrainingDay(date)) {
                                return Container(
                                  margin: const EdgeInsets.all(6.0),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.orangeAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    date.day.toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
