import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfStudioScreen extends StatefulWidget {
  const PdfStudioScreen({super.key});

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;
  String _statusMessage = '';

  // ================= CUSTOM CONTROLS =================
  // 1. Custom Page Dimensions (Default is A4: 595.27 x 841.89)
  final TextEditingController _pageWidthController = TextEditingController(
    text: '595',
  );
  final TextEditingController _pageHeightController = TextEditingController(
    text: '842',
  );

  // 2. Custom Image Quality (Slider)
  double _imageQuality = 70; // Default 70%

  // Tab 1: Image to PDF Variables
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _imageBytesList = [];
  final List<String> _imageNames = [];
  final TextEditingController _pdfNameController = TextEditingController(
    text: 'My_Document',
  );

  // Tab 2: Text to PDF Variables
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageWidthController.dispose();
    _pageHeightController.dispose();
    _pdfNameController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ================= GET CUSTOM PAGE FORMAT =================
  PdfPageFormat _getCustomPageFormat() {
    // यूज़र ने जो Width/Height डाली है, उसे पढ़ेंगे
    final double w =
        double.tryParse(_pageWidthController.text.trim()) ?? 595.27;
    final double h =
        double.tryParse(_pageHeightController.text.trim()) ?? 841.89;
    return PdfPageFormat(w, h);
  }

  // ================= 1. IMAGE TO PDF LOGIC =================
  Future<void> _pickImages() async {
    try {
      // स्लाइडर में सेट की गई क्वालिटी के हिसाब से फोटो उठाएगा
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: _imageQuality.toInt(),
      );

      if (picked.isNotEmpty) {
        for (var file in picked) {
          final bytes = await file.readAsBytes();
          _imageBytesList.add(bytes);
          _imageNames.add(file.name);
        }
        setState(() {});
      }
    } catch (e) {
      _showSnack('Error in selecting photo: $e');
    }
  }

  void _moveImage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final Uint8List itemBytes = _imageBytesList.removeAt(oldIndex);
      final String itemName = _imageNames.removeAt(oldIndex);
      _imageBytesList.insert(newIndex, itemBytes);
      _imageNames.insert(newIndex, itemName);
    });
  }

  Future<void> _generateImagePdf() async {
    if (_imageBytesList.isEmpty) {
      _showSnack('Atleast select one img or Photos');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'The custom-sized PDF is being created...';
    });

    try {
      final pw.Document pdf = pw.Document();
      final PdfPageFormat format = _getCustomPageFormat();

      for (final Uint8List bytes in _imageBytesList) {
        final pw.MemoryImage image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
            },
          ),
        );
      }

      final Uint8List pdfBytes = await pdf.save();
      String customName = _pdfNameController.text.trim();
      if (customName.isEmpty) customName = 'Images_PDF';
      if (!customName.toLowerCase().endsWith('.pdf')) {
        customName = '$customName.pdf';
      }

      await _savePdfDirectly(pdfBytes, customName);
    } catch (e) {
      _showSnack('Error in making PDF: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= 2. TEXT / CODE TO PDF LOGIC =================
  Future<void> _generateTextPdf() async {
    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();

    if (content.isEmpty) {
      _showSnack('Please write some text or code!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'The text PDF is being prepared...';
    });

    try {
      final pw.Document pdf = pw.Document();
      final PdfPageFormat format = _getCustomPageFormat();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              if (title.isNotEmpty) ...[
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 12),
              ],
              pw.Paragraph(
                text: content,
                style: const pw.TextStyle(fontSize: 13, lineSpacing: 4),
              ),
            ];
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      final String fileName =
          '${title.isEmpty ? "Notes" : title.replaceAll(' ', '_')}.pdf';

      await _savePdfDirectly(pdfBytes, fileName);
    } catch (e) {
      _showSnack('Error in making Text PDF: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ================= DIRECT SAVE HELPER =================
  Future<void> _savePdfDirectly(Uint8List pdfBytes, String fileName) async {
    try {
      if (kIsWeb) {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      } else {
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        final File file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        // फाइल का साइज़ कैलकुलेट करके दिखाएं
        final double sizeInMb = pdfBytes.lengthInBytes / (1024 * 1024);
        _showSnack(
          '✅ The PDF has been saved! (${sizeInMb.toStringAsFixed(2)} MB)\nफोल्डर: Downloads',
        );
      }
    } catch (e) {
      _showSnack('Error in saving: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  // ================= CUSTOM UI COMPONENTS =================
  Widget _buildCustomPageSize() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Page Size (Default A4 size )',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pageWidthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Width',
                    prefixIcon: Icon(Icons.swap_horiz, size: 20),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _pageHeightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    prefixIcon: Icon(Icons.swap_vert, size: 20),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomQualitySlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photo Quality: ${_imageQuality.toInt()}% (Less Quality)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Slider(
            value: _imageQuality,
            min: 10,
            max: 100,
            divisions: 90, // 10 से 100 तक स्लाइड करने के लिए
            activeColor: Colors.deepPurple,
            inactiveColor: Colors.deepPurple.shade100,
            label: '${_imageQuality.toInt()}%',
            onChanged: (val) {
              setState(() {
                _imageQuality = val;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text('Master PDF Studio'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Image to PDF'),
            Tab(icon: Icon(Icons.text_snippet), text: 'Text / Code to PDF'),
          ],
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // ================= TAB 1: Image to PDF UI =================
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Custom Image Quality Slider
                      _buildCustomQualitySlider(),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _pickImages,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text(
                                'Please Select Img',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (_imageBytesList.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              onPressed: () => setState(() {
                                _imageBytesList.clear();
                                _imageNames.clear();
                              }),
                              icon: const Icon(
                                Icons.delete_sweep,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. Custom Page Size Inputs
                      _buildCustomPageSize(),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _pdfNameController,
                        decoration: InputDecoration(
                          labelText: 'PDF file name',
                          suffixText: '.pdf',
                          prefixIcon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.deepPurple,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: _imageBytesList.isEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.deepPurple.shade100,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    '📄 No Img selected',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              )
                            : ReorderableListView.builder(
                                itemCount: _imageBytesList.length,
                                onReorder: _moveImage,
                                itemBuilder: (context, index) {
                                  return Card(
                                    key: ValueKey(
                                      'img_${index}_${_imageNames[index]}',
                                    ),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.memory(
                                          _imageBytesList[index],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      title: Text(
                                        'Page ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => setState(() {
                                          _imageBytesList.removeAt(index);
                                          _imageNames.removeAt(index);
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _generateImagePdf,
                        icon: const Icon(Icons.download),
                        label: Text(
                          'Generate Custom PDF (${_imageBytesList.length} Pages)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= TAB 2: Text to PDF UI =================
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Custom Page Size Inputs
                      _buildCustomPageSize(),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'PDF Title / Subject Name (Optional)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _contentController,
                        maxLines: 12,
                        decoration: InputDecoration(
                          labelText:
                              'Write/paste your text or C++/Java code here...',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _generateTextPdf,
                        icon: const Icon(Icons.save_alt),
                        label: const Text(
                          'Convert Text to PDF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
