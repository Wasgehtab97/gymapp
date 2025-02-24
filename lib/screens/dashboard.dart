// lib/screens/dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import '../widgets/feedback_form.dart';

class DashboardScreen extends StatefulWidget {
  /// Optionale Parameter für den aktiven Trainingsplan-Kontext:
  /// activeTrainingPlan: Liste der Geräte-IDs, currentIndex: Index der aktuellen Übung.
  /// Falls diese Parameter nicht gesetzt sind, wird deviceId aus den Route-Argumenten verwendet.
  final List<int>? activeTrainingPlan;
  final int? currentIndex;
  final int? deviceId;

  DashboardScreen({Key? key, this.activeTrainingPlan, this.currentIndex, this.deviceId})
      : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Trainingsdaten: Jeder Satz enthält Satznummer, Gewicht und Wiederholungen.
  List<Map<String, dynamic>> setsData = [
    {'setNumber': 1, 'weight': '', 'reps': ''}
  ];
  // Controller für die Eingabefelder
  final List<TextEditingController> weightControllers = [];
  final List<TextEditingController> repsControllers = [];

  List<dynamic> lastSession = [];
  String lastTrainingDate = '';
  Map<String, dynamic>? deviceInfo;
  bool isLoading = true;
  bool isFeedbackVisible = false;

  int? deviceId;
  int? userId;
  final ApiService apiService = ApiService();
  late String trainingDate;

  // Aktiver Trainingsplan-Kontext
  List<int>? activePlan;
  int? activePlanIndex;

  @override
  void initState() {
    super.initState();
    trainingDate = _formatLocalDate(DateTime.now());
    // Controller für den ersten Satz initialisieren
    weightControllers.add(TextEditingController(text: setsData[0]['weight']));
    repsControllers.add(TextEditingController(text: setsData[0]['reps']));
    _loadUserId().then((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    for (var controller in weightControllers) controller.dispose();
    for (var controller in repsControllers) controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('userId');
    });
  }

  void _initializeData() {
    final args = ModalRoute.of(context)?.settings.arguments;
    debugPrint("Route-Argumente: $args");
    if (args is Map && args.containsKey('activeTrainingPlan') && args.containsKey('currentIndex')) {
      activePlan = List<int>.from(args['activeTrainingPlan']);
      activePlanIndex = args['currentIndex'];
      deviceId = activePlan![activePlanIndex!];
    } else if (widget.deviceId != null) {
      deviceId = widget.deviceId;
    } else if (args is int) {
      deviceId = args;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ungültige oder fehlende Geräte-ID."))
        );
      });
      setState(() {
        isLoading = false;
      });
      return;
    }
    debugPrint("Setze deviceId: $deviceId");
    _fetchDeviceInfo();
    _fetchLastSession();
  }

  String _formatLocalDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  Future<void> _fetchDeviceInfo() async {
    try {
      final devices = await apiService.getDevices();
      final found = devices.firstWhere((d) => d['id'] == deviceId, orElse: () => null);
      setState(() {
        deviceInfo = found;
      });
    } catch (error) {
      debugPrint('Fehler beim Abrufen der Geräteinformationen: $error');
    }
  }

  Future<void> _fetchLastSession() async {
    if (userId == null || deviceId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    try {
      final history = await apiService.getHistory(userId!, deviceId!);
      if (history.isNotEmpty) {
        history.sort((a, b) =>
            DateTime.parse(b['training_date']).compareTo(DateTime.parse(a['training_date'])));
        final latestDate = history[0]['training_date'];
        final formattedLatest = _formatLocalDate(DateTime.parse(latestDate));
        final latestSession = history.where((entry) {
          return _formatLocalDate(DateTime.parse(entry['training_date'])) == formattedLatest;
        }).toList();
        setState(() {
          lastSession = latestSession;
          lastTrainingDate = formattedLatest;
        });
      } else {
        setState(() {
          lastSession = [];
          lastTrainingDate = "";
        });
      }
    } catch (error) {
      debugPrint("Fehler beim Abrufen der Trainingshistorie: $error");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _handleInputChange(int index, String field, String value) {
    setState(() {
      setsData[index][field] = value;
    });
  }

  void _removeLastSet() {
    if (setsData.length > 1) {
      setState(() {
        setsData.removeLast();
        weightControllers.removeLast().dispose();
        repsControllers.removeLast().dispose();
        for (int i = 0; i < setsData.length; i++) {
          setsData[i]['setNumber'] = i + 1;
        }
      });
    } else {
      setState(() {
        setsData = [{'setNumber': 1, 'weight': '', 'reps': ''}];
        weightControllers[0].text = '';
        repsControllers[0].text = '';
      });
    }
  }

  void _addSet() {
    final currentSet = setsData.last;
    final isCurrentSetValid = currentSet['weight'].toString().trim().isNotEmpty &&
        currentSet['reps'].toString().trim().isNotEmpty;
    if (!isCurrentSetValid) {
      _showAlert('Bitte fülle den aktuellen Satz vollständig aus (Gewicht und Wiederholungen)!');
      return;
    }
    setState(() {
      setsData.add({'setNumber': setsData.length + 1, 'weight': '', 'reps': ''});
      weightControllers.add(TextEditingController());
      repsControllers.add(TextEditingController());
    });
  }

  Future<void> _finishSession() async {
    if (trainingDate == lastTrainingDate) {
      _showAlert("Du hast heute bereits eine Trainingseinheit abgeschlossen.");
      return;
    }
    final exerciseName = deviceInfo != null ? deviceInfo!['name'] : "Gerät $deviceId";
    final finalData = setsData.where((set) {
      return set['weight'].toString().trim().isNotEmpty &&
          set['reps'].toString().trim().isNotEmpty;
    }).map((set) {
      return {
        'exercise': exerciseName,
        'sets': set['setNumber'],
        'reps': int.tryParse(set['reps'].toString()) ?? 0,
        'weight': double.tryParse(set['weight'].toString()) ?? 0.0,
      };
    }).toList();

    if (finalData.isEmpty) {
      _showAlert('Bitte fülle mindestens einen Satz vollständig aus, bevor du die Sitzung abschließt.');
      return;
    }
    if (userId == null || deviceId == null) {
      _showAlert("Ungültige Benutzer- oder Geräte-ID. Bitte logge dich ein.");
      return;
    }
    try {
      final trainingData = {
        'userId': userId,
        'deviceId': deviceId,
        'trainingDate': trainingDate,
        'data': finalData,
      };
      await apiService.postTrainingData(trainingData);
      _showAlert("Trainingseinheit erfolgreich gespeichert.", isSuccess: true);
      setState(() {
        lastSession = finalData;
        lastTrainingDate = trainingDate;
        setsData = [{'setNumber': 1, 'weight': '', 'reps': ''}];
        for (var controller in weightControllers) controller.dispose();
        for (var controller in repsControllers) controller.dispose();
        weightControllers.clear();
        repsControllers.clear();
        weightControllers.add(TextEditingController());
        repsControllers.add(TextEditingController());
      });
    } catch (error) {
      debugPrint("Fehler beim Speichern der Trainingsdaten: $error");
      _showAlert('Fehler beim Speichern der Trainingsdaten');
    }
  }

  void _showAlert(String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isSuccess ? "Erfolg" : "Achtung"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK"),
            )
          ],
        );
      },
    );
  }

  Widget _buildInputTable() {
    return Table(
      border: TableBorder.all(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FixedColumnWidth(60),
        2: FixedColumnWidth(60),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey),
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Satz", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Kg", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Wdh", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        ...List<TableRow>.generate(setsData.length, (index) {
          return TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(setsData[index]['setNumber'].toString(), textAlign: TextAlign.center),
              ),
              Padding(
                padding: EdgeInsets.all(4.0),
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(border: OutlineInputBorder()),
                  controller: weightControllers[index],
                  onChanged: (value) => _handleInputChange(index, 'weight', value),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(4.0),
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(border: OutlineInputBorder()),
                  controller: repsControllers[index],
                  onChanged: (value) => _handleInputChange(index, 'reps', value),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildActivePlanNavigation() {
    if (activePlan != null && activePlan!.isNotEmpty && activePlanIndex != null) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: activePlanIndex! > 0 ? _goToPreviousExercise : null,
                child: Text("Vorherige Übung"),
              ),
              ElevatedButton(
                onPressed: _endPlan,
                child: Text("Plan beenden"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              ElevatedButton(
                onPressed: activePlanIndex! < activePlan!.length - 1 ? _goToNextExercise : null,
                child: Text("Nächste Übung"),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text("Übung ${activePlanIndex! + 1} von ${activePlan!.length}"),
        ],
      );
    } else {
      return SizedBox.shrink();
    }
  }

  void _goToNextExercise() {
    if (activePlan != null && activePlanIndex != null && activePlanIndex! < activePlan!.length - 1) {
      setState(() {
        activePlanIndex = activePlanIndex! + 1;
        deviceId = activePlan![activePlanIndex!];
      });
      Navigator.pushReplacementNamed(context, '/dashboard', arguments: {
        'activeTrainingPlan': activePlan,
        'currentIndex': activePlanIndex,
      });
    }
  }

  void _goToPreviousExercise() {
    if (activePlan != null && activePlanIndex != null && activePlanIndex! > 0) {
      setState(() {
        activePlanIndex = activePlanIndex! - 1;
        deviceId = activePlan![activePlanIndex!];
      });
      Navigator.pushReplacementNamed(context, '/dashboard', arguments: {
        'activeTrainingPlan': activePlan,
        'currentIndex': activePlanIndex,
      });
    }
  }

  void _endPlan() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (deviceId == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Dashboard")),
        body: Center(child: Text("Keine gültige Geräte-ID gefunden.")),
      );
    }

    final isCurrentSetValid = setsData.last['weight'].toString().trim().isNotEmpty &&
        setsData.last['reps'].toString().trim().isNotEmpty;
    final isAnySetValid = setsData.any((set) =>
        set['weight'].toString().trim().isNotEmpty &&
        set['reps'].toString().trim().isNotEmpty);
    final isFinishDisabled = trainingDate == lastTrainingDate || !isAnySetValid;

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceInfo != null ? deviceInfo!['name'] : "Gerät $deviceId"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Datum: $trainingDate", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                  _buildInputTable(),
                  if (setsData.length > 1)
                    Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: ElevatedButton(
                        onPressed: _removeLastSet,
                        child: Text("-"),
                      ),
                    ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: isCurrentSetValid ? _addSet : null,
                        child: Text("Nächster Satz"),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: isFinishDisabled ? null : _finishSession,
                        child: Text("Fertig"),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/history', arguments: deviceId);
                    },
                    child: Text("Zur Trainingshistorie"),
                  ),
                  SizedBox(height: 24),
                  Text("Letzte Trainingseinheit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  lastTrainingDate.isNotEmpty
                      ? Text("Datum der letzten Trainingseinheit: ${_formatLocalDate(DateTime.parse(lastTrainingDate))}",
                          style: TextStyle(fontSize: 16))
                      : Text("Keine Daten der letzten Trainingseinheit vorhanden."),
                  SizedBox(height: 8),
                  if (lastSession.isNotEmpty)
                    Table(
                      border: TableBorder.all(),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: {
                        0: FixedColumnWidth(40),
                        1: FixedColumnWidth(60),
                        2: FixedColumnWidth(60),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Satz", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Kg", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Wdh", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...lastSession.map((entry) {
                          return TableRow(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(entry['sets'].toString(), textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(entry['weight'].toString(), textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(entry['reps'].toString(), textAlign: TextAlign.center),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isFeedbackVisible = !isFeedbackVisible;
                      });
                    },
                    child: Text(isFeedbackVisible ? "Feedback-Formular schließen" : "Feedback geben"),
                  ),
                  if (isFeedbackVisible)
                    Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: FeedbackForm(
                        deviceId: deviceId!,
                        onClose: () {
                          setState(() {
                            isFeedbackVisible = false;
                          });
                        },
                        onFeedbackSubmitted: (data) {
                          debugPrint("Feedback submitted: $data");
                        },
                      ),
                    ),
                  _buildActivePlanNavigation(),
                ],
              ),
            ),
    );
  }
}
