import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BmiRecord {
  final double bmi;
  final String category;
  final double weightKg;
  final double heightCm;
  final int calories;
  final DateTime date;

  BmiRecord({
    required this.bmi,
    required this.category,
    required this.weightKg,
    required this.heightCm,
    required this.calories,
    required this.date,
  });

  String get timeStr {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month} • $h:$m';
  }
}

class BmiScreen extends StatefulWidget {
  const BmiScreen({super.key});

  @override
  State<BmiScreen> createState() => _BmiScreenState();
}

class _BmiScreenState extends State<BmiScreen> {
  bool _isMale = true;
  bool _useFeetInches = false;
  bool _useLbs = false;

  int _age = 21;
  double _heightCm = 170.0;
  int _heightFeet = 5;
  int _heightInches = 7;
  double _weightKg = 65.0;
  double _weightLbs = 143.3;

  int _activityLevel = 1; // 0: Sedentary, 1: Light, 2: Moderate, 3: Active
  int _goalMode = 1; // 0: Cut (-400 kcal), 1: Maintain, 2: Bulk (+350 kcal)

  final List<BmiRecord> _history = [];

  // ==========================================
  // CORE HEALTH & BIOMETRIC CALCULATIONS
  // ==========================================
  double get _effectiveHeightCm {
    if (_useFeetInches) {
      return ((_heightFeet * 12) + _heightInches) * 2.54;
    }
    return _heightCm;
  }

  double get _effectiveWeightKg {
    if (_useLbs) {
      return _weightLbs * 0.45359237;
    }
    return _weightKg;
  }

  double get _bmi {
    final hMeters = _effectiveHeightCm / 100.0;
    if (hMeters <= 0) return 0;
    return _effectiveWeightKg / (hMeters * hMeters);
  }

  // Deurenberg Formula for Adult Body Fat %
  double get _bodyFatPercentage {
    final genderFactor = _isMale ? 1 : 0;
    final bf = (1.20 * _bmi) + (0.23 * _age) - (10.8 * genderFactor) - 5.4;
    return bf.clamp(4.0, 60.0);
  }

  double get _ponderalIndex {
    final hMeters = _effectiveHeightCm / 100.0;
    if (hMeters <= 0) return 0;
    return _effectiveWeightKg / pow(hMeters, 3);
  }

  // Mifflin-St Jeor Equation for BMR
  int get _bmr {
    final w = _effectiveWeightKg;
    final h = _effectiveHeightCm;
    final base = (10 * w) + (6.25 * h) - (5 * _age);
    return (_isMale ? base + 5 : base - 161).round();
  }

  int get _maintenanceCalories {
    const multipliers = [1.2, 1.375, 1.55, 1.725];
    return (_bmr * multipliers[_activityLevel]).round();
  }

  int get _targetCalories {
    if (_goalMode == 0) return max(1200, _maintenanceCalories - 400);
    if (_goalMode == 2) return _maintenanceCalories + 350;
    return _maintenanceCalories;
  }

  double get _waterIntakeLiters {
    return (_effectiveWeightKg * 0.035) + (_activityLevel * 0.25);
  }

  // Daily Macros (in Grams) based on Target Calories & Goal
  Map<String, int> get _macros {
    final w = _effectiveWeightKg;
    final totalKcal = _targetCalories;
    final proteinMultiplier = _goalMode == 2 ? 1.8 : (_goalMode == 0 ? 1.6 : 1.4);
    final proteinG = (w * proteinMultiplier).round();
    final fatG = ((totalKcal * 0.25) / 9).round();
    final carbsG = max(60, ((totalKcal - (proteinG * 4) - (fatG * 9)) / 4).round());

    return {
      'protein': proteinG,
      'carbs': carbsG,
      'fats': fatG,
    };
  }

  String get _idealWeightRange {
    final hMeters = _effectiveHeightCm / 100.0;
    final minKg = 18.5 * hMeters * hMeters;
    final maxKg = 24.9 * hMeters * hMeters;
    if (_useLbs) {
      return '${(minKg * 2.20462).toStringAsFixed(1)} - ${(maxKg * 2.20462).toStringAsFixed(1)} lbs';
    }
    return '${minKg.toStringAsFixed(1)} - ${maxKg.toStringAsFixed(1)} kg';
  }

  String get _weightDifferenceNote {
    final hMeters = _effectiveHeightCm / 100.0;
    final minKg = 18.5 * hMeters * hMeters;
    final maxKg = 24.9 * hMeters * hMeters;
    final current = _effectiveWeightKg;

    if (current < minKg) {
      final diff = minKg - current;
      return 'Gain ${diff.toStringAsFixed(1)} kg to reach your ideal BMI zone';
    } else if (current > maxKg) {
      final diff = current - maxKg;
      return 'Lose ${diff.toStringAsFixed(1)} kg to reach your ideal BMI zone';
    }
    return 'Perfect! You are right inside your healthy weight range.';
  }

  String get _category {
    final val = _bmi;
    if (val < 16.0) return 'Severe Thinness';
    if (val < 18.5) return 'Underweight';
    if (val < 25.0) return 'Normal Weight';
    if (val < 30.0) return 'Overweight';
    if (val < 35.0) return 'Obese Class I';
    return 'Obese Class II+';
  }

  Color get _categoryColor {
    final val = _bmi;
    if (val < 18.5) return const Color(0xFF38BDF8); // Sky Blue
    if (val < 25.0) return const Color(0xFF10B981); // Emerald Green
    if (val < 30.0) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Coral Red
  }

  void _saveToHistory() {
    setState(() {
      _history.insert(
        0,
        BmiRecord(
          bmi: _bmi,
          category: _category,
          weightKg: _effectiveWeightKg,
          heightCm: _effectiveHeightCm,
          calories: _targetCalories,
          date: DateTime.now(),
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: BMI ${_bmi.toStringAsFixed(1)} ($_category)'),
        backgroundColor: _categoryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyFullReport() {
    final m = _macros;
    final report = '''
📊 HEALTH & BIOMETRIC REPORT
• BMI: ${_bmi.toStringAsFixed(1)} kg/m² ($_category)
• Ideal Weight: $_idealWeightRange
• Est. Body Fat: ${_bodyFatPercentage.toStringAsFixed(1)}%
• Base BMR: $_bmr kcal/day
• Target Calories: $_targetCalories kcal/day
• Daily Macros: ${m['protein']}g Protein | ${m['carbs']}g Carbs | ${m['fats']}g Fats
• Water Target: ${_waterIntakeLiters.toStringAsFixed(1)} Liters/day
'''
        .trim();

    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Complete Health Report Copied to Clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _isMale = true;
      _age = 21;
      _heightCm = 170.0;
      _heightFeet = 5;
      _heightInches = 7;
      _weightKg = 65.0;
      _weightLbs = 143.3;
      _activityLevel = 1;
      _goalMode = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    final bmiVal = _bmi;
    final gaugePercent = ((bmiVal - 12.0) / (40.0 - 12.0)).clamp(0.0, 1.0);
    final macros = _macros;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'BMI & Biometric Studio',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: textColor),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Full Report',
            icon: Icon(Icons.copy_all_rounded, color: textColor),
            onPressed: _copyFullReport,
          ),
          IconButton(
            tooltip: 'Save to History',
            icon: Icon(Icons.bookmark_add_outlined, color: textColor),
            onPressed: _saveToHistory,
          ),
          IconButton(
            tooltip: 'Reset',
            icon: Icon(Icons.refresh_rounded, color: textColor),
            onPressed: _resetAll,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. HERO BMI SCORE & SPECTRUM GAUGE CARD
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _categoryColor.withValues(alpha: 0.55), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _categoryColor.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BODY MASS INDEX',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    bmiVal.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: _categoryColor,
                                      fontSize: 46,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'kg/m²',
                                    style: TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _categoryColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _categoryColor, width: 1.2),
                            ),
                            child: Text(
                              _category,
                              style: TextStyle(
                                color: _categoryColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Spectrum Gauge Bar
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 12,
                                width: barWidth,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF38BDF8), // Underweight
                                      Color(0xFF10B981), // Normal
                                      Color(0xFFF59E0B), // Overweight
                                      Color(0xFFEF4444), // Obese
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: (barWidth * gaugePercent - 10).clamp(0.0, barWidth - 20),
                                top: -4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _categoryColor, width: 4),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black45, blurRadius: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('12', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text('18.5 (Normal)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text('25.0', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text('30.0', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text('40', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.track_changes_rounded, color: _categoryColor, size: 19),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _weightDifferenceNote,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ==========================================
                // 2. GENDER & AGE CONTROLS
                // ==========================================
                Row(
                  children: [
                    Expanded(
                      child: _GenderCard(
                        label: 'Male',
                        icon: Icons.male_rounded,
                        isSelected: _isMale,
                        activeColor: const Color(0xFF3B82F6),
                        cardColor: cardColor,
                        textColor: textColor,
                        borderColor: borderColor,
                        onTap: () => setState(() => _isMale = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GenderCard(
                        label: 'Female',
                        icon: Icons.female_rounded,
                        isSelected: !_isMale,
                        activeColor: const Color(0xFFEC4899),
                        cardColor: cardColor,
                        textColor: textColor,
                        borderColor: borderColor,
                        onTap: () => setState(() => _isMale = false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==========================================
                // 3. HEIGHT & WEIGHT DUAL-UNIT CARDS
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.height_rounded, color: Color(0xFF6366F1), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Height',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor),
                              ),
                            ],
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('cm', style: TextStyle(fontSize: 12))),
                              ButtonSegment(value: true, label: Text('ft / in', style: TextStyle(fontSize: 12))),
                            ],
                            selected: {_useFeetInches},
                            onSelectionChanged: (s) => setState(() => _useFeetInches = s.first),
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_useFeetInches) ...[
                        Center(
                          child: Text(
                            '${_heightCm.toStringAsFixed(0)} cm',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
                          ),
                        ),
                        Slider(
                          value: _heightCm.clamp(100.0, 230.0),
                          min: 100.0,
                          max: 230.0,
                          divisions: 130,
                          activeColor: const Color(0xFF6366F1),
                          onChanged: (v) => setState(() => _heightCm = v),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _StepperBox(
                                title: 'Feet (ft)',
                                valueText: '$_heightFeet ft',
                                textColor: textColor,
                                subColor: subColor,
                                onMinus: () {
                                  if (_heightFeet > 3) setState(() => _heightFeet--);
                                },
                                onPlus: () {
                                  if (_heightFeet < 7) setState(() => _heightFeet++);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StepperBox(
                                title: 'Inches (in)',
                                valueText: '$_heightInches in',
                                textColor: textColor,
                                subColor: subColor,
                                onMinus: () {
                                  if (_heightInches > 0) setState(() => _heightInches--);
                                },
                                onPlus: () {
                                  if (_heightInches < 11) setState(() => _heightInches++);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Equivalent to ${_effectiveHeightCm.toStringAsFixed(1)} cm',
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.monitor_weight_outlined, color: Colors.teal, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Weight',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor),
                              ),
                            ],
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('kg', style: TextStyle(fontSize: 12))),
                              ButtonSegment(value: true, label: Text('lbs', style: TextStyle(fontSize: 12))),
                            ],
                            selected: {_useLbs},
                            onSelectionChanged: (s) => setState(() => _useLbs = s.first),
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_useLbs) ...[
                        Center(
                          child: Text(
                            '${_weightKg.toStringAsFixed(1)} kg',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
                          ),
                        ),
                        Slider(
                          value: _weightKg.clamp(25.0, 180.0),
                          min: 25.0,
                          max: 180.0,
                          divisions: 310,
                          activeColor: Colors.teal,
                          onChanged: (v) => setState(() => _weightKg = v),
                        ),
                      ] else ...[
                        Center(
                          child: Text(
                            '${_weightLbs.toStringAsFixed(1)} lbs',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
                          ),
                        ),
                        Slider(
                          value: _weightLbs.clamp(55.0, 396.0),
                          min: 55.0,
                          max: 396.0,
                          divisions: 341,
                          activeColor: Colors.teal,
                          onChanged: (v) => setState(() => _weightLbs = v),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // 4. AGE & ACTIVITY LEVEL SELECTOR
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cake_outlined, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Age: $_age years',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () {
                                  if (_age > 5) setState(() => _age--);
                                },
                                icon: const Icon(Icons.remove_rounded, size: 18),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: () {
                                  if (_age < 100) setState(() => _age++);
                                },
                                icon: const Icon(Icons.add_rounded, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Daily Activity Level',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subColor),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ChoicePill(
                            label: 'Sedentary',
                            isSelected: _activityLevel == 0,
                            onTap: () => setState(() => _activityLevel = 0),
                          ),
                          _ChoicePill(
                            label: 'Light Exercise',
                            isSelected: _activityLevel == 1,
                            onTap: () => setState(() => _activityLevel = 1),
                          ),
                          _ChoicePill(
                            label: 'Moderate',
                            isSelected: _activityLevel == 2,
                            onTap: () => setState(() => _activityLevel = 2),
                          ),
                          _ChoicePill(
                            label: 'Very Active',
                            isSelected: _activityLevel == 3,
                            onTap: () => setState(() => _activityLevel = 3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ==========================================
                // 5. 6-METRIC BIOMETRIC DASHBOARD GRID
                // ==========================================
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 560 ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.48,
                  children: [
                    _MetricInfoCard(
                      title: 'IDEAL WEIGHT',
                      value: _idealWeightRange,
                      sub: 'Healthy BMI 18.5-24.9',
                      icon: Icons.verified_rounded,
                      color: const Color(0xFF10B981),
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    _MetricInfoCard(
                      title: 'EST. BODY FAT',
                      value: '${_bodyFatPercentage.toStringAsFixed(1)}%',
                      sub: _isMale ? 'Healthy: 10% - 20%' : 'Healthy: 18% - 28%',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFFF59E0B),
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    _MetricInfoCard(
                      title: 'BASE BMR',
                      value: '$_bmr kcal',
                      sub: 'Rest metabolism',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFEF4444),
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    _MetricInfoCard(
                      title: 'DAILY TDEE',
                      value: '$_maintenanceCalories kcal',
                      sub: 'Maintenance intake',
                      icon: Icons.bolt_rounded,
                      color: const Color(0xFF6366F1),
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    _MetricInfoCard(
                      title: 'WATER INTAKE',
                      value: '${_waterIntakeLiters.toStringAsFixed(1)} Liters',
                      sub: 'Recommended daily',
                      icon: Icons.water_drop_rounded,
                      color: const Color(0xFF0EA5E9),
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    _MetricInfoCard(
                      title: 'PONDERAL INDEX',
                      value: '${_ponderalIndex.toStringAsFixed(1)} kg/m³',
                      sub: 'Normal: 11.0 - 15.0',
                      icon: Icons.analytics_outlined,
                      color: const Color(0xFFA855F7),
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ==========================================
                // 6. DAILY MACRO & CALORIE PLANNER CARD
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
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
                              Text(
                                'Daily Nutrition & Macro Split',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
                              ),
                              Text(
                                'Target: $_targetCalories kcal / day',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('Cut', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 1, label: Text('Maintain', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 2, label: Text('Bulk', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {_goalMode},
                            onSelectionChanged: (s) => setState(() => _goalMode = s.first),
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MacroBox(
                              title: 'Protein',
                              grams: '${macros['protein']}g',
                              kcal: '${macros['protein']! * 4} kcal',
                              color: const Color(0xFF10B981),
                              textColor: textColor,
                              subColor: subColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MacroBox(
                              title: 'Carbs',
                              grams: '${macros['carbs']}g',
                              kcal: '${macros['carbs']! * 4} kcal',
                              color: const Color(0xFF3B82F6),
                              textColor: textColor,
                              subColor: subColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MacroBox(
                              title: 'Fats',
                              grams: '${macros['fats']}g',
                              kcal: '${macros['fats']! * 9} kcal',
                              color: const Color(0xFFF59E0B),
                              textColor: textColor,
                              subColor: subColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // 7. SAVED HISTORY RECORDS
                // ==========================================
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved BMI History',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _history.clear()),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  ..._history.map(
                    (item) => Card(
                      color: cardColor,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: borderColor),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          child: Text(
                            item.bmi.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        title: Text(
                          item.category,
                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                        ),
                        subtitle: Text(
                          '${item.weightKg.toStringAsFixed(1)} kg • ${item.heightCm.toStringAsFixed(0)} cm • ${item.calories} kcal',
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                        trailing: Text(item.timeStr, style: TextStyle(fontSize: 11, color: subColor)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final Color cardColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _GenderCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.cardColor,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? activeColor.withValues(alpha: 0.14) : cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? activeColor : borderColor,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? activeColor : textColor.withValues(alpha: 0.6), size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isSelected ? activeColor : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperBox extends StatelessWidget {
  final String title;
  final String valueText;
  final Color textColor;
  final Color subColor;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _StepperBox({
    required this.title,
    required this.valueText,
    required this.textColor,
    required this.subColor,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: subColor)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onMinus,
                icon: Icon(Icons.remove_circle_outline_rounded, color: textColor),
              ),
              Text(
                valueText,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPlus,
                icon: Icon(Icons.add_circle_outline_rounded, color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MetricInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subColor;

  const _MetricInfoCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: subColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: textColor),
          ),
          Text(sub, style: TextStyle(fontSize: 11, color: subColor), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MacroBox extends StatelessWidget {
  final String title;
  final String grams;
  final String kcal;
  final Color color;
  final Color textColor;
  final Color subColor;

  const _MacroBox({
    required this.title,
    required this.grams,
    required this.kcal,
    required this.color,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            grams,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
          ),
          Text(
            kcal,
            style: TextStyle(fontSize: 10.5, color: subColor),
          ),
        ],
      ),
    );
  }
}