// lib/screens/profile.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import '../widgets/registration_form.dart';
import '../widgets/login_form.dart';
import '../widgets/streak_badge.dart';
import '../widgets/exp_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String storedUsername = "BeispielNutzer";
  String? token;
  int? userId;
  int expProgress = 0; // 0 bis 999
  int divisionIndex = 0; // 0: Bronze 4, 1: Bronze 3, ...
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
      expProgress = prefs.getInt('exp_progress') ?? 0;
      divisionIndex = prefs.getInt('division_index') ?? 0;
    });
    if (userId != null) {
      await Future.wait([
        _fetchStreak(),
        _fetchTrainingDates(),
      ]);
      try {
        final userData = await apiService.getUserData(userId!);
        setState(() {
          expProgress = userData['data']['exp_progress'] ?? 0;
          divisionIndex = userData['data']['division_index'] ?? 0;
        });
        await prefs.setInt('exp_progress', expProgress);
        await prefs.setInt('division_index', divisionIndex);
      } catch (e) {
        debugPrint("Fehler beim Abrufen der Benutzerdaten: $e");
      }
    }
  }
  
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
        final dates = (response['data'] as List)
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
  
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }
  
  bool _isTrainingDay(DateTime date) {
    final formatted = getLocalDateString(date);
    return trainingDates.contains(formatted);
  }
  
  @override
  Widget build(BuildContext context) {
    if (token == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Login / Registrierung", style: TextStyle(color: Colors.red)),
          backgroundColor: Colors.black,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A), Color(0xFF333333)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: const Column(
              children: [
                RegistrationForm(),
                SizedBox(height: 20),
                LoginForm(),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil", style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A), Color(0xFF333333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    if (showCalendar)
                      Card(
                        color: Colors.white.withOpacity(0.9),
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                "Trainings-Tage",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              loadingDates
                                  ? const Center(child: CircularProgressIndicator())
                                  : TableCalendar(
                                      firstDay: DateTime(2000),
                                      lastDay: DateTime(2100),
                                      focusedDay: DateTime.now(),
                                      headerStyle: const HeaderStyle(formatButtonVisible: false),
                                      calendarBuilders: CalendarBuilders(
                                        defaultBuilder: (context, date, _) {
                                          if (_isTrainingDay(date)) {
                                            return Container(
                                              margin: const EdgeInsets.all(4.0),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.deepOrange,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                date.day.toString(),
                                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _handleLogout,
                      child: const Center(child: Text("Abmelden", style: TextStyle(fontSize: 18, color: Colors.red))),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trainingsplan');
                      },
                      child: const Center(child: Text("Trainingsplan", style: TextStyle(fontSize: 18, color: Colors.red))),
                    ),
                  ],
                ),
              ),
            ),
            // Badges: StreakBadge und ExpBadge
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreakBadge(streak: streak, size: 60),
                  const SizedBox(width: 8),
                  ExpBadge(expProgress: expProgress, divisionIndex: divisionIndex, size: 60),
                ],
              ),
            ),
            // Username oben links
            Positioned(
              top: 16,
              left: 16,
              child: Text(
                storedUsername,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 50,
        color: Colors.black,
      ),
    );
  }
}
