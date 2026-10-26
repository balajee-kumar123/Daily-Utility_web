import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =========================================================================
// 1. TASK MODEL CLASS
// =========================================================================
class TodoItem {
  String id;
  String title;
  bool isDone;
  String priority;
  DateTime? dueDateTime;
  DateTime createdAt;

  TodoItem({
    required this.id,
    required this.title,
    this.isDone = false,
    this.priority = 'Personal',
    this.dueDateTime,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'priority': priority,
    'dueDateTime': dueDateTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'],
    title: json['title'],
    isDone: json['isDone'] ?? false,
    priority: json['priority'] ?? 'Personal',
    dueDateTime: json['dueDateTime'] != null
        ? DateTime.parse(json['dueDateTime'])
        : null,
    createdAt: DateTime.parse(json['createdAt']),
  );
}

// =========================================================================
// 2. MAIN TODO SCREEN
// =========================================================================
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<TodoItem> _todos = [];
  int _currentTab = 0; // 0 for Pending, 1 for Completed
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasksFromLocal();
  }

  // --- LOCAL STORAGE (SharedPreferences) LOAD ---
  Future<void> _loadTasksFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('local_todos_key');
    if (tasksString != null) {
      final List<dynamic> decoded = jsonDecode(tasksString);
      setState(() {
        _todos = decoded.map((item) => TodoItem.fromJson(item)).toList();
        _todos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    }
    setState(() => _isLoading = false);
  }

  // --- LOCAL STORAGE SAVE ---
  Future<void> _saveTasksToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_todos.map((e) => e.toJson()).toList());
    await prefs.setString('local_todos_key', encoded);
  }

  void _addTask(TodoItem item) {
    setState(() {
      _todos.insert(0, item);
    });
    _saveTasksToLocal();
  }

  void _toggleTaskStatus(String id) {
    setState(() {
      final index = _todos.indexWhere((element) => element.id == id);
      if (index != -1) {
        _todos[index].isDone = !_todos[index].isDone;
      }
    });
    _saveTasksToLocal();
  }

  void _deleteTask(String id) {
    setState(() {
      _todos.removeWhere((element) => element.id == id);
    });
    _saveTasksToLocal();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return Colors.red.shade600;
      case 'College':
        return Colors.blue.shade600;
      case 'Personal':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddTaskSheet(onTaskAdded: _addTask),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingDocs = _todos.where((t) => !t.isDone).toList();
    final completedDocs = _todos.where((t) => t.isDone).toList();

    final totalTasks = _todos.length;
    final progress = totalTasks == 0
        ? 0.0
        : (completedDocs.length / totalTasks);
    final displayDocs = _currentTab == 0 ? pendingDocs : completedDocs;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Local Smart Tasks',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        backgroundColor: Colors.orange.shade800,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "New Task",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                // --- PROGRESS CARD ---
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange.shade700,
                        Colors.deepOrange.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Offline Storage',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pendingDocs.length} Pending Tasks',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(progress * 100).toInt()}% Done',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- TABS (Pending vs Completed) ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTabButton(
                        'Pending (${pendingDocs.length})',
                        0,
                        Icons.hourglass_empty_rounded,
                      ),
                      const SizedBox(width: 12),
                      _buildTabButton(
                        'Completed (${completedDocs.length})',
                        1,
                        Icons.done_all_rounded,
                      ),
                    ],
                  ),
                ),

                // --- TASK LIST ---
                Expanded(
                  child: displayDocs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: displayDocs.length,
                          padding: const EdgeInsets.only(top: 8, bottom: 90),
                          itemBuilder: (context, index) {
                            final task = displayDocs[index];
                            String timeFormatted = '';
                            if (task.dueDateTime != null) {
                              timeFormatted = DateFormat('dd MMM, hh:mm a')
                                  .format(task.dueDateTime!);
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                elevation: 2,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.04,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  leading: InkWell(
                                    onTap: () => _toggleTaskStatus(task.id),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: task.isDone
                                              ? Colors.green
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                        color: task.isDone
                                            ? Colors.green
                                            : Colors.transparent,
                                      ),
                                      child: task.isDone
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                  title: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: task.isDone
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                      decoration: task.isDone
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color: task.isDone
                                          ? Colors.grey.shade500
                                          : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(
                                              task.priority,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            task.priority,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _getPriorityColor(
                                                task.priority,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (timeFormatted.isNotEmpty) ...[
                                          const SizedBox(width: 10),
                                          Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: Colors.orange.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeFormatted,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade300,
                                    ),
                                    onPressed: () => _deleteTask(task.id),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.orange.shade800 : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentTab == 0 ? Icons.task_alt_rounded : Icons.inbox_rounded,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            _currentTab == 0
                ? "Koi pending task nahi hai!"
                : "Aapne koi completed task nahi rakha hai.",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. ADD TASK BOTTOM SHEET WITH DATE & TIME PICKER
// =========================================================================
class _AddTaskSheet extends StatefulWidget {
  final Function(TodoItem) onTaskAdded;
  const _AddTaskSheet({required this.onTaskAdded});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final TextEditingController _taskController = TextEditingController();
  String _selectedPriority = 'Personal';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final List<String> _priorities = ['Urgent', 'College', 'Personal'];

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.orange.shade800),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(primary: Colors.orange.shade800),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
        });
      }
    }
  }

  void _submitTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    DateTime? finalDateTime;
    if (_selectedDate != null && _selectedTime != null) {
      finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    final newTask = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: text,
      priority: _selectedPriority,
      dueDateTime: finalDateTime,
      createdAt: DateTime.now(),
    );

    widget.onTaskAdded(newTask);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String dateTimeDisplay = 'Set Date & Time';
    if (_selectedDate != null && _selectedTime != null) {
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      dateTimeDisplay = DateFormat('MMM dd, hh:mm a').format(dt);
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Task',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _taskController,
            autofocus: true,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Aap kya karna chahte hain?',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Priority Tag',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _priorities.map((p) {
              final isSelected = _selectedPriority == p;
              return ChoiceChip(
                label: Text(
                  p,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                selected: isSelected,
                selectedColor: p == 'Urgent'
                    ? Colors.red.shade600
                    : (p == 'College'
                          ? Colors.blue.shade600
                          : Colors.green.shade600),
                backgroundColor: Colors.grey.shade100,
                onSelected: (val) => setState(() => _selectedPriority = p),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide.none,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedDate != null
                        ? Colors.orange.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedDate != null
                          ? Colors.orange.shade300
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: _selectedDate != null
                            ? Colors.orange.shade800
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateTimeDisplay,
                        style: TextStyle(
                          color: _selectedDate != null
                              ? Colors.orange.shade800
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _submitTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'SAVE TASK',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
