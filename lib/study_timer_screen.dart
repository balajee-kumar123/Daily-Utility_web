import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  // बिना किसी Red/Blue Error के कलर हल्का करने का सेफ फंक्शन
  Color _fade(Color c, double opacity) {
    return Color.fromRGBO(c.red, c.green, c.blue, opacity);
  }

  bool _isCountdownMode = true;
  bool _isRunning = false;
  bool _isDarkDeskMode = true;
  bool _isFullFocusMode = false;

  Timer? _timer;

  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  int _totalCountdownSeconds = 25 * 60;

  int _stopwatchSeconds = 0;
  final List<String> _laps = [];

  // शुरू में 3 ऑप्शन + खुद से जोड़ने का विकल्प
  String _selectedSubject = '💻 Coding / DSA';
  final List<String> _subjects = [];

  int _todayTotalStudyMinutes = 0;
  int _completedSessions = 0;
  final int _dailyGoalMinutes = 180;
  final List<Map<String, String>> _studyHistory = [];

  int _sessionElapsedSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showAddSubjectDialog() {
    final TextEditingController subjectController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('नया सब्जेक्ट / टॉपिक जोड़ें'),
        content: TextField(
          controller: subjectController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'जैसे: Java, C++, MySQL...',
            prefixIcon: const Icon(Icons.book, color: Colors.deepPurple),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final String newSub = subjectController.text.trim();
              if (newSub.isNotEmpty) {
                final String formattedSub = '📖 $newSub';
                setState(() {
                  if (!_subjects.contains(formattedSub)) {
                    _subjects.add(formattedSub);
                  }
                  _selectedSubject = formattedSub;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _toggleTimer() {
    HapticFeedback.lightImpact();
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _sessionElapsedSeconds++;

          if (_sessionElapsedSeconds % 60 == 0) {
            _todayTotalStudyMinutes++;
          }

          if (_isCountdownMode) {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
            } else {
              _timer?.cancel();
              _isRunning = false;
              _completedSessions++;
              HapticFeedback.heavyImpact();
              _logSession('$_selectedMinutes min Focus Completed');
              _showCompletionDialog();
            }
          } else {
            _stopwatchSeconds++;
          }
        });
      });
    }
  }

  void _resetTimer() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();

    if (!_isCountdownMode && _stopwatchSeconds >= 60) {
      final int mins = (_stopwatchSeconds / 60).floor();
      _completedSessions++;
      _logSession('$mins min Stopwatch Study');
    }

    setState(() {
      _isRunning = false;
      _sessionElapsedSeconds = 0;
      if (_isCountdownMode) {
        _remainingSeconds = _selectedMinutes * 60;
        _totalCountdownSeconds = _selectedMinutes * 60;
      } else {
        _stopwatchSeconds = 0;
        _laps.clear();
      }
    });
  }

  void _setPresetMinutes(int mins) {
    _timer?.cancel();
    setState(() {
      _isCountdownMode = true;
      _isRunning = false;
      _selectedMinutes = mins;
      _remainingSeconds = mins * 60;
      _totalCountdownSeconds = mins * 60;
      _sessionElapsedSeconds = 0;
    });
  }

  void _recordLap() {
    if (!_isCountdownMode && _stopwatchSeconds > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _laps.insert(
          0,
          'Lap ${_laps.length + 1}:  ${_formatTime(_stopwatchSeconds)}',
        );
      });
    }
  }

  void _logSession(String durationText) {
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _studyHistory.insert(0, {
      'subject': _selectedSubject,
      'duration': durationText,
      'time': timeStr,
    });
  }

  void _showCustomTimeDialog() {
    final TextEditingController customController = TextEditingController(
      text: _selectedMinutes.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Custom Study Time'),
        content: TextField(
          controller: customController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'कितने मिनट पढ़ना है? (e.g. 45)',
            border: OutlineInputBorder(),
            suffixText: 'mins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final int? mins = int.tryParse(customController.text.trim());
              if (mins != null && mins > 0 && mins <= 300) {
                _setPresetMinutes(mins);
                Navigator.pop(context);
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('शानदार Balajee भाई! 🎉'),
          ],
        ),
        content: Text(
          'आपने $_selectedSubject का $_selectedMinutes मिनट का फोकस सेशन पूरा कर लिया है! अब 5 मिनट का छोटा ब्रेक ले सकते हैं।',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setPresetMinutes(5);
            },
            child: const Text('☕ 5 Min Break लें'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetTimer();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String mStr = minutes.toString().padLeft(2, '0');
    final String sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final String hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    final Color bgColor = _isDarkDeskMode
        ? const Color(0xFF090D16)
        : const Color(0xFFF3F4F8);
    final Color cardColor = _isDarkDeskMode
        ? const Color(0xFF131B2E)
        : Colors.white;
    final Color textColor = _isDarkDeskMode ? Colors.white : Colors.black87;
    final Color accentColor = _isCountdownMode
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF14B8A6);

    final double progress = _isCountdownMode
        ? (_totalCountdownSeconds > 0
              ? _remainingSeconds / _totalCountdownSeconds
              : 0)
        : ((_stopwatchSeconds % 60) / 60.0);

    final double dailyGoalProgress =
        (_todayTotalStudyMinutes / _dailyGoalMinutes).clamp(0.0, 1.0);

    final bool hideExtraControls = _isRunning || _isFullFocusMode;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Study Focus Desk Clock'),
        backgroundColor: _isDarkDeskMode
            ? const Color(0xFF090D16)
            : Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Full Focus Mode',
            icon: Icon(
              _isFullFocusMode ? Icons.fullscreen_exit : Icons.fullscreen,
            ),
            onPressed: () =>
                setState(() => _isFullFocusMode = !_isFullFocusMode),
          ),
          IconButton(
            tooltip: 'Dark / Light Mode',
            icon: Icon(_isDarkDeskMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkDeskMode = !_isDarkDeskMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Mode & Subject Controls (टाइमर चलते ही छुप जाएंगे)
            if (!hideExtraControls) ...[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!_isCountdownMode) {
                            _timer?.cancel();
                            setState(() {
                              _isCountdownMode = true;
                              _isRunning = false;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isCountdownMode
                                ? accentColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '⏳ Focus Timer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isCountdownMode
                                    ? Colors.white
                                    : textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_isCountdownMode) {
                            _timer?.cancel();
                            setState(() {
                              _isCountdownMode = false;
                              _isRunning = false;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isCountdownMode
                                ? accentColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '⏱️ Stopwatch',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !_isCountdownMode
                                    ? Colors.white
                                    : textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Subject Selector Row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🎯 अभी क्या पढ़ रहे हो?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _fade(textColor, 0.75),
                          ),
                        ),
                        InkWell(
                          onTap: _showAddSubjectDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_circle,
                                  size: 16,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'खुद से जोड़ें',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._subjects.map((subj) {
                            final bool isSelected = _selectedSubject == subj;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InputChip(
                                label: Text(subj),
                                selected: isSelected,
                                selectedColor: Colors.deepPurple.shade100,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.deepPurple.shade900
                                      : Colors.black87,
                                ),
                                onSelected: (_) =>
                                    setState(() => _selectedSubject = subj),
                                onDeleted: _subjects.length > 1
                                    ? () {
                                        setState(() {
                                          _subjects.remove(subj);
                                          if (_selectedSubject == subj) {
                                            _selectedSubject = _subjects.first;
                                          }
                                        });
                                      }
                                    : null,
                              ),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.deepPurple,
                            ),
                            label: const Text(
                              'Add New',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _showAddSubjectDialog,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 2. GIANT 70%+ SCREEN STUDY TIMER CARD
            Container(
              constraints: BoxConstraints(
                minHeight: hideExtraControls
                    ? screenHeight * 0.78
                    : screenHeight * 0.68,
              ),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: _fade(accentColor, 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: _fade(accentColor, 0.35), width: 2.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _fade(accentColor, 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _selectedSubject,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Giant Circular Ring + Huge Digital Time
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 290,
                        height: 290,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          backgroundColor: _fade(accentColor, 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _formatTime(
                                  _isCountdownMode
                                      ? _remainingSeconds
                                      : _stopwatchSeconds,
                                ),
                                style: TextStyle(
                                  fontSize: 74,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: textColor,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _isRunning
                                    ? _fade(Colors.green, 0.2)
                                    : _fade(Colors.orange, 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _isRunning
                                    ? '🔥 DEEP FOCUS MODE ON'
                                    : '⏸️ READY TO FOCUS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: _isRunning
                                      ? Colors.greenAccent.shade400
                                      : Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (_isCountdownMode && !_isRunning) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildPresetChip('🍅 25m', 25),

                        ActionChip(
                          avatar: const Icon(Icons.edit, size: 15),
                          label: const Text('Custom'),
                          onPressed: _showCustomTimeDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Big Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _fade(accentColor, 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 30,
                          color: textColor,
                          onPressed: _resetTimer,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Reset',
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning
                              ? Colors.orange.shade800
                              : accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 34,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 8,
                        ),
                        onPressed: _toggleTimer,
                        icon: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow,
                          size: 32,
                        ),
                        label: Text(
                          _isRunning ? 'PAUSE' : 'START STUDY',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (!_isCountdownMode) ...[
                        const SizedBox(width: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: _fade(accentColor, 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 30,
                            color: textColor,
                            onPressed: _recordLap,
                            icon: const Icon(Icons.flag),
                            tooltip: 'Record Lap',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Today's Study Progress Card
            if (!_isFullFocusMode) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📊 Today Study (Goal: 3 Hrs)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '$_todayTotalStudyMinutes / $_dailyGoalMinutes mins',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: dailyGoalProgress,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade800,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBox(
                            '⏱️ Total Studied',
                            '$_todayTotalStudyMinutes mins',
                            accentColor,
                            textColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatBox(
                            '🏆 Sessions Done',
                            '$_completedSessions',
                            Colors.amber,
                            textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (!_isCountdownMode && _laps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏁 Stopwatch Laps',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Divider(),
                    ..._laps.map(
                      (lap) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          lap,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_studyHistory.isNotEmpty && !_isFullFocusMode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📜 Today\'s Completed Sessions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    const Divider(),
                    ..._studyHistory.map(
                      (item) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                        title: Text(
                          item['subject']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          item['duration']!,
                          style: TextStyle(color: _fade(textColor, 0.7)),
                        ),
                        trailing: Text(
                          item['time']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _fade(textColor, 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int mins) {
    final bool isSelected = _selectedMinutes == mins;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.deepPurple.shade100,
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.deepPurple.shade900 : Colors.black87,
      ),
      onSelected: (_) => _setPresetMinutes(mins),
    );
  }

  Widget _buildStatBox(
    String label,
    String value,
    Color color,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fade(color, 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: _fade(textColor, 0.7)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
