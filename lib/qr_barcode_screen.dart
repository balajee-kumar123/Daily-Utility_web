import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QrBarcodeScreen extends StatefulWidget {
  const QrBarcodeScreen({super.key});

  @override
  State<QrBarcodeScreen> createState() => _QrBarcodeScreenState();
}

class _QrBarcodeScreenState extends State<QrBarcodeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mode: 0 = QR Code, 1 = Barcode
  int _selectedMode = 0;

  // QR Template Types: 'text', 'upi', 'wifi', 'whatsapp', 'contact'
  String _qrTemplate = 'text';

  // Barcode Format Types
  String _barcodeFormat = 'Code 128';
  final List<String> _barcodeFormats = [
    'Code 128',
    'Code 39',
    'EAN 13 (12 Digits)',
    'UPC-A (11 Digits)',
  ];

  // Input Controllers
  final TextEditingController _mainTextCtrl = TextEditingController(
    text: 'https://google.com',
  );
  final TextEditingController _customTitleCtrl = TextEditingController(
    text: 'Scan Me',
  );

  // UPI Controllers
  final TextEditingController _upiIdCtrl = TextEditingController();
  final TextEditingController _upiNameCtrl = TextEditingController();
  final TextEditingController _upiAmountCtrl = TextEditingController();

  // Wi-Fi Controllers
  final TextEditingController _wifiSsidCtrl = TextEditingController();
  final TextEditingController _wifiPassCtrl = TextEditingController();
  String _wifiSecurity = 'WPA';

  // WhatsApp Controllers
  final TextEditingController _waPhoneCtrl = TextEditingController();
  final TextEditingController _waMsgCtrl = TextEditingController();

  // Contact (vCard) Controllers
  final TextEditingController _cNameCtrl = TextEditingController();
  final TextEditingController _cPhoneCtrl = TextEditingController();
  final TextEditingController _cEmailCtrl = TextEditingController();

  // Styling Colors
  Color _fgColor = const Color(0xFF1A1F36);
  Color _bgColor = Colors.white;

  final List<Color> _fgPalette = [
    const Color(0xFF1A1F36),
    Colors.indigo.shade800,
    Colors.deepPurple.shade800,
    Colors.teal.shade800,
    Colors.red.shade800,
    Colors.green.shade800,
    Colors.blue.shade900,
  ];

  final List<Color> _bgPalette = [
    Colors.white,
    const Color(0xFFF8FAFC),
    const Color(0xFFFFFBEB),
    const Color(0xFFF0FDF4),
    const Color(0xFFEFF6FF),
    const Color(0xFFFAF5FF),
  ];

  // Saved History
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedMode = _tabController.index;
          if (_selectedMode == 1 &&
              (_mainTextCtrl.text.isEmpty ||
                  _mainTextCtrl.text.startsWith('http'))) {
            _mainTextCtrl.text = 'BALAJEE-2026';
          }
        });
      }
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('qr_barcode_history');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() {
        _history = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  Future<void> _saveToHistory() async {
    final payload = _generatedData;
    if (payload.isEmpty) return;

    final newItem = {
      'title': _customTitleCtrl.text.trim().isEmpty
          ? (_selectedMode == 0 ? 'QR Code' : _barcodeFormat)
          : _customTitleCtrl.text.trim(),
      'data': payload,
      'type': _selectedMode == 0 ? 'QR ($_qrTemplate)' : _barcodeFormat,
      'time': DateTime.now().toIso8601String(),
    };

    setState(() {
      _history.insert(0, newItem);
      if (_history.length > 20) _history.removeLast();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qr_barcode_history', jsonEncode(_history));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to History!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Final Payload String Builder
  String get _generatedData {
    if (_selectedMode == 1) {
      final raw = _mainTextCtrl.text.trim();
      return raw.isEmpty ? '123456789012' : raw;
    }

    switch (_qrTemplate) {
      case 'upi':
        final id = _upiIdCtrl.text.trim().isEmpty
            ? 'merchant@upi'
            : _upiIdCtrl.text.trim();
        final name = Uri.encodeComponent(
          _upiNameCtrl.text.trim().isEmpty ? 'User' : _upiNameCtrl.text.trim(),
        );
        final amt = _upiAmountCtrl.text.trim();
        String url = 'upi://pay?pa=$id&pn=$name&cu=INR';
        if (amt.isNotEmpty) url += '&am=$amt';
        return url;

      case 'wifi':
        final ssid = _wifiSsidCtrl.text.trim().isEmpty
            ? 'MyWiFi'
            : _wifiSsidCtrl.text.trim();
        final pass = _wifiPassCtrl.text.trim();
        return 'WIFI:T:$_wifiSecurity;S:$ssid;P:$pass;;';

      case 'whatsapp':
        final phone = _waPhoneCtrl.text.trim().replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final msg = Uri.encodeComponent(_waMsgCtrl.text.trim());
        return 'https://wa.me/${phone.isEmpty ? '919876543210' : phone}?text=$msg';

      case 'contact':
        final name = _cNameCtrl.text.trim().isEmpty
            ? 'Balajee Kumar'
            : _cNameCtrl.text.trim();
        final phone = _cPhoneCtrl.text.trim();
        final email = _cEmailCtrl.text.trim();
        return 'BEGIN:VCARD\nVERSION:3.0\nFN:$name\nTEL:$phone\nEMAIL:$email\nEND:VCARD';

      case 'text':
      default:
        final t = _mainTextCtrl.text.trim();
        return t.isEmpty ? 'https://flutter.dev' : t;
    }
  }

  Barcode _getBarcodeType() {
    if (_selectedMode == 0) return Barcode.qrCode();
    switch (_barcodeFormat) {
      case 'Code 39':
        return Barcode.code39();
      case 'EAN 13 (12 Digits)':
        return Barcode.ean13();
      case 'UPC-A (11 Digits)':
        return Barcode.upcA();
      case 'Code 128':
      default:
        return Barcode.code128();
    }
  }

  // Print Single High-Res Card or A4 Sticker Sheet (12 Stickers)
  Future<void> _exportPdf({required bool isStickerSheet}) async {
    final doc = pw.Document();
    final barcodeType = _getBarcodeType();
    final data = _generatedData;
    final label = _customTitleCtrl.text.trim().isEmpty
        ? 'Scan Code'
        : _customTitleCtrl.text.trim();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          if (!isStickerSheet) {
            // Single Large Poster / Standee Card
            return pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(32),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.indigo800, width: 3),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      label.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 24),
                    pw.BarcodeWidget(
                      barcode: barcodeType,
                      data: data,
                      width: _selectedMode == 0 ? 220 : 320,
                      height: _selectedMode == 0 ? 220 : 110,
                      drawText: _selectedMode == 1,
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      data.length > 60 ? '${data.substring(0, 60)}...' : data,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated via Daily Utility Hub',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // A4 Sticker Sheet (12 Stickers Grid for Products/Shops)
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Printable Sticker Sheet - $label (12x)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: List.generate(12, (index) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.grey400,
                            width: 1,
                          ),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              label,
                              maxLines: 1,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.BarcodeWidget(
                              barcode: barcodeType,
                              data: data,
                              width: _selectedMode == 0 ? 95 : 130,
                              height: _selectedMode == 0 ? 95 : 55,
                              drawText: _selectedMode == 1,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: isStickerSheet ? 'Sticker_Sheet_12x.pdf' : 'QR_Barcode_Poster.pdf',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mainTextCtrl.dispose();
    _customTitleCtrl.dispose();
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    _upiAmountCtrl.dispose();
    _wifiSsidCtrl.dispose();
    _wifiPassCtrl.dispose();
    _waPhoneCtrl.dispose();
    _waMsgCtrl.dispose();
    _cNameCtrl.dispose();
    _cPhoneCtrl.dispose();
    _cEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          'QR & Barcode Studio Pro',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3.5,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_2_rounded), text: 'Smart QR Code'),
            Tab(icon: Icon(Icons.barcode_reader), text: 'Product Barcode'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Saved History',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistorySheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= 1. LIVE PREVIEW CARD =================
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: _fgColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // Badge Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _fgColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _customTitleCtrl.text.trim().isEmpty
                            ? 'SCAN ME'
                            : _customTitleCtrl.text.trim().toUpperCase(),
                        style: TextStyle(
                          color: _fgColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Barcode / QR Widget
                    BarcodeWidget(
                      barcode: _getBarcodeType(),
                      data: _generatedData,
                      width: _selectedMode == 0 ? 200 : 280,
                      height: _selectedMode == 0 ? 200 : 100,
                      color: _fgColor,
                      backgroundColor: _bgColor,
                      drawText: _selectedMode == 1,
                      style: TextStyle(
                        color: _fgColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      errorBuilder: (context, error) => Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        child: Text(
                          'Invalid format for $_barcodeFormat!\nUse valid digits/characters.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Encoded Payload Preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 15, color: _fgColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _generatedData,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _fgColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _generatedData),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payload copied to clipboard!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Icon(Icons.copy, size: 15, color: _fgColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ================= 2. EXPORT & PRINT ACTION BUTTONS =================
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _exportPdf(isStickerSheet: false),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text(
                      'Print Poster PDF',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _exportPdf(isStickerSheet: true),
                    icon: const Icon(Icons.grid_on_rounded, size: 20),
                    label: const Text(
                      '12x Sticker Sheet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  tooltip: 'Save to History',
                  onPressed: _saveToHistory,
                  icon: const Icon(
                    Icons.bookmark_add_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ================= 3. TEMPLATE / FORMAT SELECTOR =================
            if (_selectedMode == 0) ...[
              const Text(
                'Select Smart QR Template',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTemplateChip('text', 'Link / Text', Icons.language),
                    _buildTemplateChip(
                      'upi',
                      'UPI Payment',
                      Icons.currency_rupee,
                    ),
                    _buildTemplateChip('wifi', 'Wi-Fi Login', Icons.wifi),
                    _buildTemplateChip('whatsapp', 'WhatsApp', Icons.chat),
                    _buildTemplateChip(
                      'contact',
                      'vCard Contact',
                      Icons.contact_mail,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Select Barcode Standard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _barcodeFormat,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _barcodeFormats
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _barcodeFormat = val;
                      if (val.startsWith('EAN 13')) {
                        _mainTextCtrl.text = '890123456789';
                      } else if (val.startsWith('UPC-A')) {
                        _mainTextCtrl.text = '12345678901';
                      } else {
                        _mainTextCtrl.text = 'BALAJEE-2026';
                      }
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 18),

            // ================= 4. DYNAMIC INPUT FORM CARD =================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _customTitleCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Shop or Brand Name',
                      prefixIcon: Icon(Icons.label_important_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDynamicFormFields(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= 5. COLOR CUSTOMIZATION STUDIO =================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Color Studio (Customize Look)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Code Color:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _fgPalette.map((color) {
                      final bool isSelected = _fgColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _fgColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.amber
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Background Card Color:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 71, 32, 155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _bgPalette.map((color) {
                      final bool isSelected = _bgColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _bgColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String key, String label, IconData icon) {
    final bool selected = _qrTemplate == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : Colors.indigo,
        ),
        label: Text(label),
        selected: selected,
        selectedColor: const Color.fromARGB(255, 6, 222, 114),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.white,
        onSelected: (_) {
          setState(() {
            _qrTemplate = key;
            if (key == 'upi') _customTitleCtrl.text = 'Scan & Pay via UPI';
            if (key == 'wifi') _customTitleCtrl.text = 'Scan to Join Wi-Fi';
            if (key == 'whatsapp') _customTitleCtrl.text = 'Chat on WhatsApp';
            if (key == 'contact') _customTitleCtrl.text = 'Save My Contact';
            if (key == 'text') _customTitleCtrl.text = 'Scan Me';
          });
        },
      ),
    );
  }

  Widget _buildDynamicFormFields() {
    if (_selectedMode == 1 || _qrTemplate == 'text') {
      return TextField(
        controller: _mainTextCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: _selectedMode == 1
              ? 'Product ID'
              : 'Enter Website URL or Any Text',
          prefixIcon: const Icon(Icons.edit_note_rounded),
          border: const OutlineInputBorder(),
        ),
      );
    }

    switch (_qrTemplate) {
      case 'upi':
        return Column(
          children: [
            TextField(
              controller: _upiIdCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'UPI ID (e.g. balajee@okaxis)',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upiNameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Payee / Shop Name (e.g. Balajee Kumar)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upiAmountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Fixed Amount in ₹ (Optional)',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case 'wifi':
        return Column(
          children: [
            TextField(
              controller: _wifiSsidCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Wi-Fi Network Name (SSID)',
                prefixIcon: Icon(Icons.wifi),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wifiPassCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Wi-Fi Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _wifiSecurity,
              decoration: const InputDecoration(
                labelText: 'Security Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA / WPA2')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                DropdownMenuItem(
                  value: 'nopass',
                  child: Text('Open (No Password)'),
                ),
              ],
              onChanged: (v) => setState(() => _wifiSecurity = v!),
            ),
          ],
        );

      case 'whatsapp':
        return Column(
          children: [
            TextField(
              controller: _waPhoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText:
                    'WhatsApp Number with Country Code (e.g. 919876543210)',
                prefixIcon: Icon(Icons.phone_android),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _waMsgCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Pre-filled Message (e.g. Hello Balajee!)',
                prefixIcon: Icon(Icons.message_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case 'contact':
        return Column(
          children: [
            TextField(
              controller: _cNameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cPhoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved QR & Barcodes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_history.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('qr_barcode_history');
                        setState(() => _history.clear());
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _history.isEmpty
                    ? const Center(
                        child: Text(
                          'No saved codes yet. Click the bookmark button to save!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade50,
                              child: const Icon(
                                Icons.qr_code,
                                color: Colors.indigo,
                              ),
                            ),
                            title: Text(
                              item['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item['type']} • ${item['data']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: item['data']),
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied from history!'),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
