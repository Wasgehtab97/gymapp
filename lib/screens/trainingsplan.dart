import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';

class TrainingsplanScreen extends StatefulWidget {
  TrainingsplanScreen({Key? key}) : super(key: key);

  @override
  _TrainingsplanScreenState createState() => _TrainingsplanScreenState();
}

class _TrainingsplanScreenState extends State<TrainingsplanScreen> {
  bool isLoggedIn = false;
  bool isLoading = true;
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> trainingPlans = [];
  int? userId;

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoadPlans();
  }

  Future<void> _checkLoginAndLoadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getString('token') != null;
      userId = prefs.getInt('userId');
    });
    if (!isLoggedIn || userId == null) {
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
      await _loadTrainingPlans();
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadTrainingPlans() async {
    try {
      List<dynamic> plans = await apiService.getTrainingPlans(userId!);
      setState(() {
        trainingPlans = List<Map<String, dynamic>>.from(plans);
      });
    } catch (e) {
      debugPrint('Error loading training plans: $e');
    }
  }

  Future<void> _createNewPlan(String name) async {
    try {
      final result = await apiService.createTrainingPlan(userId!, name);
      setState(() {
        trainingPlans.add(Map<String, dynamic>.from(result['data']));
      });
    } catch (e) {
      debugPrint('Error creating training plan: $e');
    }
  }

  Future<void> _deletePlan(int planId) async {
    try {
      await apiService.deleteTrainingPlan(planId);
      setState(() {
        trainingPlans.removeWhere((plan) => plan['id'] == planId);
      });
    } catch (e) {
      debugPrint('Error deleting training plan: $e');
    }
  }

  Future<void> _startPlan(int planId) async {
    try {
      final result = await apiService.startTrainingPlan(planId);
      List<dynamic> exerciseOrder = result['data']['exerciseOrder'];
      if (exerciseOrder.isNotEmpty) {
        Navigator.pushNamed(context, '/dashboard', arguments: {
          'activeTrainingPlan': exerciseOrder,
          'currentIndex': 0,
        });
      } else {
        debugPrint("exerciseOrder ist leer!");
      }
    } catch (e) {
      debugPrint('Error starting training plan: $e');
    }
  }

  Future<void> _showCreatePlanDialog() async {
    String planName = "";
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Neuen Trainingsplan erstellen"),
          content: TextField(
            decoration: const InputDecoration(labelText: "Name des Plans"),
            onChanged: (value) {
              planName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                if (planName.trim().isNotEmpty) {
                  _createNewPlan(planName.trim());
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Erstellen"),
            ),
          ],
        );
      },
    );
  }

  void _editPlan(Map<String, dynamic> plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTrainingPlanScreen(
          plan: plan,
          onPlanUpdated: (updatedPlan) {
            setState(() {
              int index = trainingPlans.indexWhere((p) => p['id'] == updatedPlan['id']);
              if (index != -1) {
                trainingPlans[index] = updatedPlan;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(plan['name']),
        subtitle: Text("Übungen: " +
            (plan['exercises'] != null
                ? (plan['exercises'] as List)
                    .map((e) => e['device_name'])
                    .join(", ")
                : "Keine Übungen")),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editPlan(plan);
            } else if (value == 'delete') {
              _deletePlan(plan['id']);
            } else if (value == 'start') {
              _startPlan(plan['id']);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text("Bearbeiten")),
            const PopupMenuItem(value: 'start', child: Text("Plan starten")),
            const PopupMenuItem(value: 'delete', child: Text("Löschen")),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanList() {
    if (trainingPlans.isEmpty) {
      return const Center(child: Text("Keine Trainingspläne vorhanden."));
    }
    return ListView.builder(
      itemCount: trainingPlans.length,
      itemBuilder: (context, index) {
        final plan = trainingPlans[index];
        return _buildPlanCard(plan);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trainingsplan')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPlanList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlanDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EditTrainingPlanScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Function(Map<String, dynamic>)? onPlanUpdated;

  EditTrainingPlanScreen({Key? key, required this.plan, this.onPlanUpdated})
      : super(key: key);

  @override
  _EditTrainingPlanScreenState createState() => _EditTrainingPlanScreenState();
}

class _EditTrainingPlanScreenState extends State<EditTrainingPlanScreen> {
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> exercises = [];
  List<dynamic> availableDevices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.plan['exercises'] != null) {
      exercises = List<Map<String, dynamic>>.from(widget.plan['exercises']);
    }
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      availableDevices = await apiService.getDevices();
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading devices: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addExercise(dynamic device) {
    setState(() {
      exercises.add({
        'device_id': device['id'],
        'device_name': device['name'],
        'exercise_order': exercises.length + 1,
      });
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = exercises.removeAt(oldIndex);
      exercises.insert(newIndex, item);
      for (int i = 0; i < exercises.length; i++) {
        exercises[i]['exercise_order'] = i + 1;
      }
    });
  }

  Future<void> _savePlanChanges() async {
    try {
      final updatedPlan = await apiService.updateTrainingPlan(widget.plan['id'], exercises);
      if (widget.onPlanUpdated != null) {
        widget.onPlanUpdated!(updatedPlan['data']);
      }
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating training plan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trainingsplan bearbeiten")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text("Übung hinzufügen: "),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<dynamic>(
                          isExpanded: true,
                          hint: const Text("Wähle ein Gerät"),
                          items: availableDevices.map((device) {
                            return DropdownMenuItem<dynamic>(
                              value: device,
                              child: Text(device['name']),
                            );
                          }).toList(),
                          onChanged: (device) {
                            if (device != null) _addExercise(device);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView(
                    onReorder: _onReorder,
                    children: exercises.asMap().entries.map((entry) {
                      final index = entry.key;
                      final exercise = entry.value;
                      return ListTile(
                        key: ValueKey('${exercise['device_id']}_$index'),
                        title: Text(exercise['device_name']),
                        trailing: const Icon(Icons.drag_handle),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _savePlanChanges,
                    child: const Text("Änderungen speichern"),
                  ),
                )
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.close),
      ),
    );
  }
}
