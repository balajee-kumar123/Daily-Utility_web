import 'package:flutter/material.dart';

import 'dart:math';

// ============================================================================
// 1. MAIN HUB SCREEN (DASHBOARD)
// ============================================================================
class CalculatorHubScreen extends StatelessWidget {
  const CalculatorHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> calculators = [
      {
        'title': 'Age',
        'icon': Icons.cake_rounded,
        'color': Colors.pink,
        'screen': const AgeCalcScreen(),
      },
      {
        'title': 'Percentage',
        'icon': Icons.percent_rounded,
        'color': Colors.blue,
        'screen': const PercentageCalcScreen(),
      },
      {
        'title': 'CGPA',
        'icon': Icons.school_rounded,
        'color': Colors.purple,
        'screen': const CgpaCalcScreen(),
      },
      {
        'title': 'Attendance',
        'icon': Icons.co_present_rounded,
        'color': Colors.teal,
        'screen': const AttendanceCalcScreen(),
      },
      {
        'title': 'EMI',
        'icon': Icons.account_balance_rounded,
        'color': Colors.indigo,
        'screen': const EmiCalcScreen(),
      },
      {
        'title': 'Discount',
        'icon': Icons.local_offer_rounded,
        'color': Colors.orange,
        'screen': const DiscountCalcScreen(),
      },
      {
        'title': 'GST',
        'icon': Icons.receipt_long_rounded,
        'color': Colors.green,
        'screen': const GstCalcScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Calculator Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: calculators.length,
        itemBuilder: (context, index) {
          final calc = calculators[index];
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => calc['screen']),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: calc['color'].withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: calc['color'].withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: calc['color'].withOpacity(0.15),
                    child: Icon(calc['icon'], size: 30, color: calc['color']),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    calc['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS (To save code lines)
// ============================================================================
Widget buildInput(
  String label,
  TextEditingController controller, {
  String? suffix,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

Widget buildResult(String text, Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: color.withValues(alpha: 0.8),
      ),
    ),
  );
}

// ============================================================================
// 2. AGE CALCULATOR
// ============================================================================
class AgeCalcScreen extends StatefulWidget {
  const AgeCalcScreen({super.key});
  @override
  State<AgeCalcScreen> createState() => _AgeCalcScreenState();
}

class _AgeCalcScreenState extends State<AgeCalcScreen> {
  DateTime? dob;
  String result = "Select your Date of Birth";

  void calculateAge() {
    if (dob == null) return;
    DateTime today = DateTime.now();
    int years = today.year - dob!.year;
    int months = today.month - dob!.month;
    int days = today.day - dob!.day;
    if (months < 0 || (months == 0 && days < 0)) {
      years--;
      months += (months < 0 ? 12 : 11);
      days += 30;
    }
    setState(() => result = "$years Years, $months Months, $days Days");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Age Calculator'),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => dob = picked);
                  calculateAge();
                }
              },
              icon: const Icon(Icons.calendar_month),
              label: Text(
                dob == null
                    ? "Choose Date of Birth"
                    : "${dob!.day}-${dob!.month}-${dob!.year}",
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
              ),
            ),
            const SizedBox(height: 30),
            buildResult(result, Colors.pink),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. PERCENTAGE CALCULATOR
// ============================================================================
class PercentageCalcScreen extends StatefulWidget {
  const PercentageCalcScreen({super.key});
  @override
  State<PercentageCalcScreen> createState() => _PercentageCalcScreenState();
}

class _PercentageCalcScreenState extends State<PercentageCalcScreen> {
  final valCtrl = TextEditingController();
  final percentCtrl = TextEditingController();
  String result = "0.00";

  void calculate() {
    double val = double.tryParse(valCtrl.text) ?? 0;
    double pct = double.tryParse(percentCtrl.text) ?? 0;
    setState(() => result = ((val * pct) / 100).toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Percentage Calculator'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildInput("What is", percentCtrl, suffix: "%"),
            buildInput("of Amount", valCtrl),
            ElevatedButton(
              onPressed: calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Calculate"),
            ),
            const SizedBox(height: 20),
            buildResult("Result: $result", Colors.blue),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. ATTENDANCE CALCULATOR (BCA Life Saver!)
// ============================================================================
class AttendanceCalcScreen extends StatefulWidget {
  const AttendanceCalcScreen({super.key});
  @override
  State<AttendanceCalcScreen> createState() => _AttendanceCalcScreenState();
}

class _AttendanceCalcScreenState extends State<AttendanceCalcScreen> {
  final totalCtrl = TextEditingController();
  final attendedCtrl = TextEditingController();
  final targetCtrl = TextEditingController(text: "75");
  String result = "Enter details to check status";

  void calculate() {
    double total = double.tryParse(totalCtrl.text) ?? 0;
    double attended = double.tryParse(attendedCtrl.text) ?? 0;
    double target = double.tryParse(targetCtrl.text) ?? 75;

    if (total == 0 || attended > total) {
      setState(() => result = "Invalid Input!");
      return;
    }

    double currentPct = (attended / total) * 100;
    if (currentPct >= target) {
      double bunk = (attended - (target / 100 * total)) / (target / 100);
      setState(
        () => result =
            "Current: ${currentPct.toStringAsFixed(1)}%\nYou can safely bunk ${bunk.floor()} classes.",
      );
    } else {
      double req = ((target / 100 * total) - attended) / (1 - (target / 100));
      setState(
        () => result =
            "Current: ${currentPct.toStringAsFixed(1)}%\nYou need to attend ${req.ceil()} more classes continuously.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: const Text('Attendance Calculator'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildInput("Total Classes Held", totalCtrl),
            buildInput("Classes Attended", attendedCtrl),
            buildInput("Target Percentage", targetCtrl, suffix: "%"),
            ElevatedButton(
              onPressed: calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Calculate"),
            ),
            const SizedBox(height: 20),
            buildResult(result, Colors.teal),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. EMI CALCULATOR
// ============================================================================
class EmiCalcScreen extends StatefulWidget {
  const EmiCalcScreen({super.key});
  @override
  State<EmiCalcScreen> createState() => _EmiCalcScreenState();
}

class _EmiCalcScreenState extends State<EmiCalcScreen> {
  final amountCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final monthsCtrl = TextEditingController();
  String result = "0.00";

  void calculate() {
    double p = double.tryParse(amountCtrl.text) ?? 0;
    double r = (double.tryParse(rateCtrl.text) ?? 0) / 12 / 100;
    double n = double.tryParse(monthsCtrl.text) ?? 0;

    if (p == 0 || r == 0 || n == 0) return;
    double emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    double total = emi * n;
    setState(
      () => result =
          "Monthly EMI: ₹${emi.toStringAsFixed(2)}\nTotal Interest: ₹${(total - p).toStringAsFixed(2)}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: const Text('EMI Calculator'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildInput("Loan Amount (₹)", amountCtrl),
            buildInput("Interest Rate (p.a)", rateCtrl, suffix: "%"),
            buildInput("Tenure (Months)", monthsCtrl),
            ElevatedButton(
              onPressed: calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Calculate"),
            ),
            const SizedBox(height: 20),
            buildResult(result, Colors.indigo),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. CGPA CALCULATOR (Simple Semester Average)
// ============================================================================
class CgpaCalcScreen extends StatefulWidget {
  const CgpaCalcScreen({super.key});
  @override
  State<CgpaCalcScreen> createState() => _CgpaCalcScreenState();
}

class _CgpaCalcScreenState extends State<CgpaCalcScreen> {
  List<TextEditingController> sgpaCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  String result = "0.00";

  void calculate() {
    double total = 0;
    int count = 0;
    for (var ctrl in sgpaCtrls) {
      double val = double.tryParse(ctrl.text) ?? 0;
      if (val > 0) {
        total += val;
        count++;
      }
    }
    setState(
      () => result = count > 0
          ? "CGPA: ${(total / count).toStringAsFixed(2)}\nPercentage: ${((total / count) * 9.5).toStringAsFixed(1)}%"
          : "0.00",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple.shade50,
      appBar: AppBar(
        title: const Text('CGPA Calculator'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: sgpaCtrls.length,
                itemBuilder: (context, i) =>
                    buildInput("Semester ${i + 1} SGPA", sgpaCtrls[i]),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        setState(() => sgpaCtrls.add(TextEditingController())),
                    child: const Text("+ Add Sem"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: calculate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Calculate"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            buildResult(result, Colors.purple),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. DISCOUNT CALCULATOR
// ============================================================================
class DiscountCalcScreen extends StatefulWidget {
  const DiscountCalcScreen({super.key});
  @override
  State<DiscountCalcScreen> createState() => _DiscountCalcScreenState();
}

class _DiscountCalcScreenState extends State<DiscountCalcScreen> {
  final priceCtrl = TextEditingController();
  final discCtrl = TextEditingController();
  String result = "0.00";

  void calculate() {
    double price = double.tryParse(priceCtrl.text) ?? 0;
    double disc = double.tryParse(discCtrl.text) ?? 0;
    double saved = (price * disc) / 100;
    setState(
      () => result =
          "Pay Amount: ₹${(price - saved).toStringAsFixed(2)}\nYou Saved: ₹${saved.toStringAsFixed(2)}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text('Discount Calculator'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildInput("Original Price (₹)", priceCtrl),
            buildInput("Discount", discCtrl, suffix: "%"),
            ElevatedButton(
              onPressed: calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Calculate"),
            ),
            const SizedBox(height: 20),
            buildResult(result, Colors.orange),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 8. GST CALCULATOR
// ============================================================================
class GstCalcScreen extends StatefulWidget {
  const GstCalcScreen({super.key});
  @override
  State<GstCalcScreen> createState() => _GstCalcScreenState();
}

class _GstCalcScreenState extends State<GstCalcScreen> {
  final amountCtrl = TextEditingController();
  double gstRate = 18;
  String result = "0.00";

  void calculate(bool addGst) {
    double amt = double.tryParse(amountCtrl.text) ?? 0;
    if (addGst) {
      double gst = (amt * gstRate) / 100;
      setState(
        () => result =
            "Net Price: ₹$amt\nGST ($gstRate%): ₹${gst.toStringAsFixed(2)}\nTotal (Inclusive): ₹${(amt + gst).toStringAsFixed(2)}",
      );
    } else {
      double net = amt - (amt * (100 / (100 + gstRate)));
      setState(
        () => result =
            "Original Price: ₹${(amt - net).toStringAsFixed(2)}\nGST Removed: ₹${net.toStringAsFixed(2)}\nTotal: ₹$amt",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('GST Calculator'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildInput("Amount (₹)", amountCtrl),
            Wrap(
              spacing: 10,
              children: [5.0, 12.0, 18.0, 28.0]
                  .map(
                    (rate) => ChoiceChip(
                      label: Text("$rate%"),
                      selected: gstRate == rate,
                      onSelected: (val) => setState(() => gstRate = rate),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => calculate(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("- Remove GST"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => calculate(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("+ Add GST"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            buildResult(result, Colors.green),
          ],
        ),
      ),
    );
  }
}
