import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import '../widgets/feedback_form.dart'; // WICHTIG: FeedbackForm importieren

class DashboardScreen extends StatefulWidget {
  final List<int>? activeTrainingPlan;
  final int? currentIndex;
  final int? deviceId;
  final String? exercise;

  const DashboardScreen({
    Key? key,
    this.activeTrainingPlan,
    this.currentIndex,
    this.deviceId,
    this.exercise,
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> setsData = [
    {'setNumber': 1, 'weight': '', 'reps': ''}
  ];
  final List<TextEditingController> weightControllers = [];
  final List<TextEditingController> repsControllers = [];

  List<dynamic> lastSession = [];
  String lastTrainingDate = "";
  Map<String, dynamic>? deviceInfo;
  bool isLoading = true;
  bool isFeedbackVisible = false;
  bool trainingCompletedToday = false;

  int? deviceId;
  int? userId;
  final ApiService apiService = ApiService();
  late String trainingDate;

  // Variablen für Trainingsplan und Übungsauswahl
  List<int>? activePlan;
  int? activePlanIndex;
  String? selectedExercise;

  bool _initialized = false;

  // Dummy-Liste für Übungsauswahl im "multi"-Modus
  final List<String> multiExerciseOptions = [
    "Benchpress",
    "Squat",
    "Deadlift"
  ];

  @override
  void initState() {
    super.initState();
    trainingDate = _formatLocalDate(DateTime.now());
    weightControllers.add(TextEditingController(text: setsData[0]['weight']));
    repsControllers.add(TextEditingController(text: setsData[0]['reps']));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _init();
      _initialized = true;
    }
  }

  Future<void> _init() async {
    await _loadUserId();
    _initializeData();
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
    if (args is Map) {
      if (args.containsKey('secretCode') && args.containsKey('deviceId')) {
        final secretCode = args['secretCode'];
        final receivedDeviceId = args['deviceId'];
        apiService.getDeviceBySecret(receivedDeviceId, secretCode).then((device) {
          setState(() {
            deviceId = device['id'];
            deviceInfo = device;
          });
        }).catchError((error) {
          debugPrint('Fehler beim Abrufen des Geräts mit secretCode: $error');
        });
      } else if (args.containsKey('activeTrainingPlan') && args.containsKey('currentIndex')) {
        activePlan = List<int>.from(args['activeTrainingPlan']);
        activePlanIndex = args['currentIndex'];
        deviceId = activePlan![activePlanIndex!];
      } else if (args.containsKey('deviceId')) {
        deviceId = args['deviceId'];
      }
      if (args.containsKey('exercise')) {
        selectedExercise = args['exercise'];
      }
    } else if (widget.deviceId != null) {
      deviceId = widget.deviceId;
    }
    if (widget.exercise != null) {
      selectedExercise = widget.exercise;
    }
    _fetchLastSession();
    _fetchDeviceInfo();
  }

  String _formatLocalDate(DateTime date) {
    final germanDate = date.toUtc().add(const Duration(hours: 1));
    final y = germanDate.year.toString();
    final m = germanDate.month.toString().padLeft(2, '0');
    final d = germanDate.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  Future<void> _fetchDeviceInfo() async {
    if (deviceId != null) {
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
  }

  Future<void> _fetchLastSession() async {
    if (userId == null || deviceId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    try {
      final history = selectedExercise != null
          ? await apiService.getHistory(userId!, exercise: selectedExercise)
          : await apiService.getHistory(userId!, deviceId: deviceId!);
      if (history.isNotEmpty) {
        history.sort((a, b) =>
            DateTime.parse(b['training_date']).compareTo(DateTime.parse(a['training_date'])));
        final latestDate = history[0]['training_date'];
        final formattedLatest = _formatLocalDate(DateTime.parse(latestDate));
        final today = _formatLocalDate(DateTime.now());
        setState(() {
          lastSession = history
              .where((entry) =>
                  _formatLocalDate(DateTime.parse(entry['training_date'])) == formattedLatest)
              .toList();
          lastTrainingDate = formattedLatest;
          trainingCompletedToday = (today == formattedLatest);
        });
      } else {
        setState(() {
          lastSession = [];
          lastTrainingDate = "";
          trainingCompletedToday = false;
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
    if (trainingCompletedToday) {
      _showAlert("Du warst hier heute schonmal");
      return;
    }
    final exerciseName =
        selectedExercise ?? (deviceInfo != null ? deviceInfo!['name'] : "Gerät $deviceId");
    final finalData = setsData
        .where((set) =>
            set['weight'].toString().trim().isNotEmpty &&
            set['reps'].toString().trim().isNotEmpty)
        .map((set) {
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
        trainingCompletedToday = true;
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
      String errorMessage = error.toString();
      if (errorMessage.contains("Du warst hier heute schonmal")) {
        _showAlert("Du warst hier heute schonmal");
      } else {
        _showAlert('Fehler beim Speichern der Trainingsdaten');
      }
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
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }

  /// Widget zur Auswahl im "multi"-Modus
  Widget _buildMultiExerciseSelection() {
    return Column(
      children: [
        Text(
          "Bitte wähle eine Übung:",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          children: multiExerciseOptions.map((exerciseOption) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  selectedExercise = exerciseOption;
                  _fetchLastSession();
                });
              },
              child: Text(
                exerciseOption,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInputTable() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FixedColumnWidth(70),
            2: FixedColumnWidth(70),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[300]),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Satz",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Kg",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Wdh",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
              ],
            ),
            ...List<TableRow>.generate(setsData.length, (index) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      setsData[index]['setNumber'].toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      controller: weightControllers[index],
                      onChanged: (value) => _handleInputChange(index, 'weight', value),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      controller: repsControllers[index],
                      onChanged: (value) => _handleInputChange(index, 'reps', value),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePlanNavigation() {
    if (activePlan != null && activePlan!.isNotEmpty && activePlanIndex != null) {
      return Card(
        elevation: 6,
        margin: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: activePlanIndex! > 0 ? _goToPreviousExercise : null,
                    child: Text(
                      "Vorherige Übung",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _endPlan,
                    child: Text(
                      "Plan beenden",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: activePlanIndex! < activePlan!.length - 1 ? _goToNextExercise : null,
                    child: Text(
                      "Nächste Übung",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Übung ${activePlanIndex! + 1} von ${activePlan!.length}",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ],
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
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
        appBar: AppBar(
          title: Text(
            "Dashboard",
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        ),
        body: Center(
          child: Text(
            "Keine gültige Geräte-ID gefunden.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final isCurrentSetValid = setsData.last['weight'].toString().trim().isNotEmpty &&
        setsData.last['reps'].toString().trim().isNotEmpty;
    final isAnySetValid = setsData.any((set) =>
        set['weight'].toString().trim().isNotEmpty &&
        set['reps'].toString().trim().isNotEmpty);
    final isFinishDisabled = trainingCompletedToday || !isAnySetValid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedExercise != null
              ? "${selectedExercise!} – ${deviceInfo != null ? deviceInfo!['name'] : "Gerät $deviceId"}"
              : deviceInfo != null ? deviceInfo!['name'] : "Gerät $deviceId",
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A), Color(0xFF333333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Datum: $trainingDate",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16)),
                    const SizedBox(height: 16),
                    if (deviceInfo != null &&
                        deviceInfo!['exercise_mode'].toString().toLowerCase() == 'multi' &&
                        selectedExercise == null)
                      _buildMultiExerciseSelection()
                    else
                      _buildInputTable(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                          onPressed: isCurrentSetValid ? _addSet : null,
                          child: Text("Nächster Satz",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                          onPressed: isFinishDisabled ? null : _finishSession,
                          child: Text("Fertig",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/history', arguments: {
                          'deviceId': deviceId,
                          if (selectedExercise != null) 'exercise': selectedExercise,
                        });
                      },
                      child: Text("Zur Trainingshistorie",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                    Text("Letzte Trainingseinheit",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            )),
                    const SizedBox(height: 8),
                    lastTrainingDate.isNotEmpty
                        ? Text("Datum: ${_formatLocalDate(DateTime.parse(lastTrainingDate))}",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16))
                        : Text("Keine Daten vorhanden.", style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    if (lastSession.isNotEmpty)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Table(
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            columnWidths: const {
                              0: FixedColumnWidth(40),
                              1: FixedColumnWidth(60),
                              2: FixedColumnWidth(60),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey[400]),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("Satz",
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.secondary,
                                            )),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("Kg",
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.secondary,
                                            )),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("Wdh",
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.secondary,
                                            )),
                                  ),
                                ],
                              ),
                              ...List<TableRow>.generate(setsData.length, (index) {
                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(setsData[index]['setNumber'].toString(),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.secondary,
                                              )),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        controller: weightControllers[index],
                                        onChanged: (value) => _handleInputChange(index, 'weight', value),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        controller: repsControllers[index],
                                        onChanged: (value) => _handleInputChange(index, 'reps', value),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          isFeedbackVisible = !isFeedbackVisible;
                        });
                      },
                      child: Text(
                        isFeedbackVisible ? "Feedback-Formular schließen" : "Feedback geben",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
                      ),
                    ),
                    if (isFeedbackVisible)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
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
      ),
    );
  }
}
