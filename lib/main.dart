// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'screens/history.dart';
import 'screens/profile.dart';
import 'screens/reporting_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/trainingsplan.dart';
import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Progress Tracking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/dashboard':
            return MaterialPageRoute(
              builder: (context) => DashboardScreen(),
              settings: settings,  // Hier werden die Route-Argumente mitgegeben
            );
          case '/history':
            return MaterialPageRoute(
              builder: (context) => HistoryScreen(),
              settings: settings,
            );
          case '/profile':
            return MaterialPageRoute(
              builder: (context) => ProfileScreen(),
              settings: settings,
            );
          case '/reporting':
            return MaterialPageRoute(
              builder: (context) => ReportDashboardScreen(),
              settings: settings,
            );
          case '/admin':
            return MaterialPageRoute(
              builder: (context) => AdminDashboardScreen(),
              settings: settings,
            );
          case '/trainingsplan':
            return MaterialPageRoute(
              builder: (context) => TrainingsplanScreen(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const HomePage(),
              settings: settings,
            );
        }
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const HomePage(),
        settings: settings,
      ),
    );
  }
}
