import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Map<String, dynamic>> _expenses = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedCategory = 'Food';
  bool _isLoading = true;

  // Monthly Filter Variables
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _showAllMonths = false;

  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _categories = [
    'Food',
    'Travel',
    'Shopping',
    'Recharge',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  String get _storageKey {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        return 'expenses_${user.email}';
      }
    } catch (_) {}
    return 'expenses_balajee_default';
  }

  DateTime _parseDate(dynamic dateVal) {
    if (dateVal is DateTime) return dateVal;
    if (dateVal is String) {
      return DateTime.tryParse(dateVal) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _formatDate(dynamic dateVal) {
    final dt = _parseDate(dateVal);
    final day = dt.day.toString().padLeft(2, '0');
    final month = _monthNames[dt.month - 1].substring(0, 3);
    return '$day $month ${dt.year}';
  }

  // Selected Month ke hisaab se Expenses Filter karega
  List<Map<String, dynamic>> get _filteredExpenses {
    if (_showAllMonths) return _expenses;
    return _expenses.where((expense) {
      final dt = _parseDate(expense['date']);
      return dt.month == _selectedMonth && dt.year == _selectedYear;
    }).toList();
  }

  // Selected Month ka Total Kharcha
  double get _filteredTotalExpenses {
    double total = 0;
    for (var expense in _filteredExpenses) {
      total += (expense['amount'] as num).toDouble();
    }
    return total;
  }

  void _changeMonth(int offset) {
    setState(() {
      _showAllMonths = false;
      _selectedMonth += offset;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
  }

  // 1. Load Expenses (Local + Cloud Firestore)
  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localData = prefs.getString(_storageKey);

    if (localData != null) {
      final List<dynamic> decoded = jsonDecode(localData);
      setState(() {
        _expenses = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .get();

        if (snapshot.docs.isNotEmpty) {
          final cloudList = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? '',
              'amount': (data['amount'] as num? ?? 0).toDouble(),
              'category': data['category'] ?? 'Food',
              'date': data['date'] ?? DateTime.now().toIso8601String(),
            };
          }).toList();

          cloudList.sort(
            (a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])),
          );

          setState(() {
            _expenses = cloudList;
          });
          await prefs.setString(_storageKey, jsonEncode(_expenses));
        }
      }
    } catch (e) {
      debugPrint('Cloud Sync skipped (using local DB): $e');
    }
  }

  // 2. Add Expense
  Future<void> _addExpense(String title, double amount, String category) async {
    final now = DateTime.now();
    final String id = now.millisecondsSinceEpoch.toString();
    final Map<String, dynamic> newExpense = {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': now.toIso8601String(),
    };

    setState(() {
      _expenses.insert(0, newExpense);
      _selectedMonth = now.month;
      _selectedYear = now.year;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_expenses));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(id)
            .set(newExpense);
      }
    } catch (e) {
      debugPrint('Cloud save skipped: $e');
    }
  }

  // 3. Delete Expense
  Future<void> _deleteExpense(Map<String, dynamic> expenseItem) async {
    setState(() {
      _expenses.removeWhere((e) => e['id'] == expenseItem['id']);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_expenses));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && expenseItem['id'] != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(expenseItem['id'].toString())
            .delete();
      }
    } catch (_) {}
  }

  // 4. Print / Export Monthly PDF Statement
  Future<void> _printMonthlyReport() async {
    final items = _filteredExpenses;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Is mahine print karne ke liye koi expense nahi hai!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final String periodTitle = _showAllMonths
        ? 'All Time Expenses'
        : '${_monthNames[_selectedMonth - 1]} $_selectedYear';

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Daily Utility Hub - Expense Report',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Statement Period: $periodTitle',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Total: Rs. ${_filteredTotalExpenses.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Date', 'Item Title', 'Category', 'Amount (Rs.)'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green700,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              data: List<List<String>>.generate(items.length, (index) {
                final exp = items[index];
                final amt = (exp['amount'] as num).toDouble();
                return [
                  '${index + 1}',
                  _formatDate(exp['date']),
                  exp['title'].toString(),
                  exp['category'].toString(),
                  'Rs. ${amt.toStringAsFixed(2)}',
                ];
              }),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Grand Total ($periodTitle): Rs. ${_filteredTotalExpenses.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Expense_Report_${periodTitle.replaceAll(' ', '_')}.pdf',
    );
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Add Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'What did you buy? (e.g. Samosa)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _titleController.clear();
                    _amountController.clear();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final String title = _titleController.text.trim();
                    final double? amount = double.tryParse(
                      _amountController.text.trim(),
                    );

                    if (title.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter valid item and amount!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    _addExpense(title, amount, _selectedCategory);
                    Navigator.pop(dialogContext);
                    _titleController.clear();
                    _amountController.clear();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.fastfood;
      case 'Travel':
        return Icons.directions_bus;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Recharge':
        return Icons.phone_android;
      default:
        return Icons.money;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayedExpenses = _filteredExpenses;
    final String currentPeriodLabel = _showAllMonths
        ? 'All Time Spent'
        : '${_monthNames[_selectedMonth - 1]} $_selectedYear Spent';

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _printMonthlyReport,
            tooltip: 'Print / Download PDF Report',
            icon: const Icon(Icons.print_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month Selector Bar
                Container(
                  margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.green,
                        ),
                        tooltip: 'Previous Month',
                        onPressed: () => _changeMonth(-1),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showAllMonths = !_showAllMonths;
                          });
                        },
                        child: Column(
                          children: [
                            Text(
                              _showAllMonths
                                  ? 'Showing: All Months'
                                  : '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _showAllMonths
                                  ? 'Tap to filter by month'
                                  : 'Tap to view All Time',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.green,
                        ),
                        tooltip: 'Next Month',
                        onPressed: () => _changeMonth(1),
                      ),
                    ],
                  ),
                ),

                // Total Spent Card + Quick Print Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade700],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        currentPeriodLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '₹${_filteredTotalExpenses.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _printMonthlyReport,
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Print / Save Monthly PDF',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Expense List for Selected Month
                Expanded(
                  child: displayedExpenses.isEmpty
                      ? Center(
                          child: Text(
                            _showAllMonths
                                ? 'No expenses yet. Click + to add!'
                                : 'No expenses in ${_monthNames[_selectedMonth - 1]} $_selectedYear.\nClick + to add!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: displayedExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = displayedExpenses[index];
                            final double amount = (expense['amount'] as num)
                                .toDouble();

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: Icon(
                                    _getCategoryIcon(
                                      expense['category'] ?? 'Other',
                                    ),
                                    color: Colors.green,
                                  ),
                                ),
                                title: Text(
                                  expense['title'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${expense['category'] ?? 'Other'} • ${_formatDate(expense['date'])}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => _deleteExpense(expense),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
