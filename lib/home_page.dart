// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/gym.dart';
import 'screens/profile.dart';
import 'screens/report_dashboard.dart';  // Korrekte Datei
import 'screens/admin_dashboard.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String? userRole;
  bool _roleLoaded = false;

  final List<Widget> _defaultPages = [
    GymScreen(),
    ProfileScreen(),
    ReportDashboardScreen(), // Korrekt
  ];

  final Widget _adminPage = AdminDashboardScreen();

  List<Widget> get _pages {
    if (userRole == 'admin') {
      return [..._defaultPages, _adminPage];
    }
    return _defaultPages;
  }

  List<BottomNavigationBarItem> get _navigationItems {
    List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center),
        label: 'Gym',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profil',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart),
        label: 'Reporting',
      ),
    ];
    if (userRole == 'admin') {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      );
    }
    return items;
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString('role');
    debugPrint('Geladene Rolle: $role');
    setState(() {
      userRole = role;
      _roleLoaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentIndex >= _pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: _navigationItems,
      ),
    );
  }
}
