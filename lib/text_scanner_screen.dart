import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TextScannerScreen extends StatefulWidget {
  const TextScannerScreen({super.key});

  @override
  State<TextScannerScreen> createState() => _TextScannerScreenState();
}

class _TextScannerScreenState extends State<TextScannerScreen> {
  final String _ocrApiKey = dotenv.env['OCR_API_KEY'] ??
      dotenv.env['OCR_SPACE_API_KEY'] ??
      'helloworld';

  Uint8List? _originalImageBytes;
  Uint8List? _croppedImageBytes;
  bool _isScanning = false;
  bool _isSpeaking = false;
  String _selectedLang = 'eng'; // 'eng' = English, 'hin' = Hindi
  String _scanMode = 'Paragraph'; // 'Paragraph' (Engine 1) or 'Code/Receipt' (Engine 2)

  final TextEditingController _extractedTextController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();

  double _speechRate = 0.5; // 0.5 in flutter_tts = 1.0x normal speed

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _extractedTextController.dispose();
    super.dispose();
  }

  // Smart Text Formatter: Fixes 1-word-per-line issues automatically
  String _cleanExtractedText(String raw, {bool forceSingleParagraph = false}) {
    if (raw.trim().isEmpty) return '';

    String text = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ');

    if (forceSingleParagraph) {
      List<String> paragraphs = text.split(RegExp(r'\n\s*\n'));
      return paragraphs
          .map((p) =>
              p.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((p) => p.isNotEmpty)
          .join('\n\n');
    }

    List<String> lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '';

    // Check if OCR broke words into separate lines (e.g., >45% of lines have <= 2 words)
    if (lines.length > 2) {
      int shortLines =
          lines.where((l) => l.split(RegExp(r'\s+')).length <= 2).length;
      if (shortLines / lines.length >= 0.45) {
        return lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }

    // Natural sentence stitcher
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      final String current = lines[i];
      buffer.write(current);

      if (i < lines.length - 1) {
        final bool endsWithStop = RegExp(r'[.?!।:|—]$').hasMatch(current);
        final bool nextIsList =
            RegExp(r'^(\d+[\.\)]|[\•\-\*])\s').hasMatch(lines[i + 1]);
        if (endsWithStop || nextIsList) {
          buffer.write('\n');
        } else {
          buffer.write(' ');
        }
      }
    }

    return buffer.toString().replaceAll(RegExp(r' +'), ' ').trim();
  }

  Future<void> _pickImageAndOpenCropper(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 92,
      );

      if (pickedFile == null) return;

      final Uint8List rawBytes = await pickedFile.readAsBytes();
      setState(() {
        _originalImageBytes = rawBytes;
      });

      if (!mounted) return;
      await _openCropStudio(rawBytes);
    } catch (e) {
      _showSnack('Could not load image: $e');
    }
  }

  Future<void> _openCropStudio(Uint8List sourceBytes) async {
    final Uint8List? croppedResult = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProCropStudioScreen(imageBytes: sourceBytes),
      ),
    );

    if (croppedResult != null) {
      setState(() {
        _croppedImageBytes = croppedResult;
      });
      await _performOcr(croppedResult);
    }
  }

  Future<void> _performOcr(Uint8List imageBytes) async {
    setState(() => _isScanning = true);

    try {
      final String base64Image =
          'data:image/png;base64,${base64Encode(imageBytes)}';

      // Engine 1 is always required for Hindi & natural paragraphs
      final String engineToUse =
          (_selectedLang == 'hin' || _scanMode == 'Paragraph') ? '1' : '2';

      final response = await http.post(
        Uri.parse('https://api.ocr.space/parse/image'),
        headers: {
          'apikey': _ocrApiKey.trim(),
        },
        body: {
          'base64Image': base64Image,
          'language': _selectedLang,
          'isOverlayRequired': 'false',
          'scale': 'true',
          'isTable': 'false',
          'OCREngine': engineToUse,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List? parsedResults = data['ParsedResults'];

        if (parsedResults != null && parsedResults.isNotEmpty) {
          final String rawText =
              (parsedResults[0]['ParsedText'] ?? '').toString().trim();

          final String cleanedText = _cleanExtractedText(rawText);

          setState(() {
            _extractedTextController.text = cleanedText.isEmpty
                ? 'No readable text detected in this area. Try cropping closer to the text.'
                : cleanedText;
          });
        } else {
          final String err =
              (data['ErrorMessage'] ?? 'Could not recognize text.').toString();
          _showSnack(err);
        }
      } else {
        _showSnack('OCR Server Error (${response.statusCode})');
      }
    } catch (e) {
      _showSnack('Connection error. Please check your internet.');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _toggleVoiceReader() async {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) {
      _showSnack('Extract or type some text first to listen.');
      return;
    }

    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      await _flutterTts.setLanguage(_selectedLang == 'hin' ? 'hi-IN' : 'en-IN');
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(1.0);
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
    }
  }

  void _copyText() {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) {
      _showSnack('Nothing to copy yet!');
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard!');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentText = _extractedTextController.text.trim();
    final int wordCount =
        currentText.isEmpty ? 0 : currentText.split(RegExp(r'\s+')).length;
    final int charCount = _extractedTextController.text.length;
    final int lineCount =
        currentText.isEmpty ? 0 : currentText.split('\n').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vision OCR Studio',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Smart Crop • Paragraph AI • Voice Reader',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_croppedImageBytes != null || currentText.isNotEmpty)
            IconButton(
              tooltip: 'Reset Workspace',
              onPressed: () {
                _flutterTts.stop();
                setState(() {
                  _originalImageBytes = null;
                  _croppedImageBytes = null;
                  _extractedTextController.clear();
                  _isSpeaking = false;
                });
              },
              icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFFF87171)),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. TOP DARK HERO CONTROL DECK
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Language & Mode Segmented Bar
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(
                      children: [
                        _buildLangTab('eng', '🇬🇧 English'),
                        const SizedBox(width: 6),
                        _buildLangTab('hin', '🇮🇳 हिंदी (Hindi)'),
                        const Spacer(),
                        // Mode badge
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _scanMode = _scanMode == 'Paragraph'
                                  ? 'Receipt/Numbers'
                                  : 'Paragraph';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: Color(0xFF38BDF8),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _scanMode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dual Upload & Camera Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildCaptureButton(
                          title: 'Upload Photo',
                          subtitle: 'Gallery & Crop',
                          icon: Icons.add_photo_alternate_rounded,
                          isPrimary: true,
                          onTap: _isScanning
                              ? null
                              : () => _pickImageAndOpenCropper(ImageSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCaptureButton(
                          title: 'Scan Camera',
                          subtitle: 'Snap & Crop',
                          icon: Icons.camera_enhance_rounded,
                          isPrimary: false,
                          onTap: _isScanning
                              ? null
                              : () => _pickImageAndOpenCropper(ImageSource.camera),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 2. CROPPED IMAGE PREVIEW CARD (Shows when image is selected)
                  if (_croppedImageBytes != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isScanning
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isScanning
                                      ? 'AI Scanning in Progress...'
                                      : 'Cropped Region Ready',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const Spacer(),
                                if (_originalImageBytes != null)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: const Color(0xFF4F46E5),
                                    ),
                                    onPressed: _isScanning
                                        ? null
                                        : () => _openCropStudio(_originalImageBytes!),
                                    icon: const Icon(Icons.crop_rounded, size: 15),
                                    label: const Text(
                                      'Re-Crop',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: const Color(0xFF0F172A),
                                  ),
                                  onPressed: _isScanning
                                      ? null
                                      : () => _performOcr(_croppedImageBytes!),
                                  icon: const Icon(Icons.refresh_rounded, size: 15),
                                  label: const Text(
                                    'Rescan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(maxHeight: 165),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    _croppedImageBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                if (_isScanning)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withOpacity(0.82),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Color(0xFF38BDF8),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Reading lines...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 3. COMPACT AI VOICE PLAYER BAR
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF312E81).withOpacity(0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleVoiceReader,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _isSpeaking
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isSpeaking
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isSpeaking
                                    ? 'Speaking Aloud...'
                                    : 'AI Voice Reader',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedLang == 'hin'
                                    ? 'Hindi Voice Engine Ready'
                                    : 'English Voice Engine Ready',
                                style: const TextStyle(
                                  color: Color(0xFFA5B4FC),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Speed Selector Pills
                        ...[0.38, 0.5, 0.65, 0.8].map((rate) {
                          final String label = rate == 0.38
                              ? '0.75x'
                              : rate == 0.5
                                  ? '1x'
                                  : rate == 0.65
                                      ? '1.25x'
                                      : '1.5x';
                          final bool active = (_speechRate - rate).abs() < 0.05;
                          return GestureDetector(
                            onTap: () => setState(() => _speechRate = rate),
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: active
                                      ? const Color(0xFF1E1B4B)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. SMART TEXT WORKSPACE CARD
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header + Action Toolbar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.article_rounded,
                                size: 19,
                                color: Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Extracted Text Studio',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              // 1-Click Copy Button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _copyText,
                                icon: const Icon(Icons.copy_rounded, size: 15),
                                label: const Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quick Text Cleanup Chips (Fixes broken lines in 1 click)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              _buildTextToolChip(
                                icon: Icons.wrap_text_rounded,
                                label: 'Join Broken Lines',
                                onTap: () {
                                  if (currentText.isEmpty) return;
                                  setState(() {
                                    _extractedTextController.text =
                                        _cleanExtractedText(
                                      _extractedTextController.text,
                                      forceSingleParagraph: true,
                                    );
                                  });
                                  _showSnack(
                                    'All broken lines merged into clean sentences!',
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildTextToolChip(
                                icon: Icons.space_bar_rounded,
                                label: 'Clean Extra Spaces',
                                onTap: () {
                                  if (currentText.isEmpty) return;
                                  setState(() {
                                    _extractedTextController.text =
                                        _extractedTextController.text
                                            .replaceAll(RegExp(r'[ \t]+'), ' ')
                                            .trim();
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildTextToolChip(
                                icon: Icons.text_fields_rounded,
                                label: 'UPPERCASE',
                                onTap: () {
                                  if (currentText.isEmpty) return;
                                  setState(() {
                                    _extractedTextController.text =
                                        _extractedTextController.text
                                            .toUpperCase();
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildTextToolChip(
                                icon: Icons.format_size,
                                label: 'lowercase',
                                onTap: () {
                                  if (currentText.isEmpty) return;
                                  setState(() {
                                    _extractedTextController.text =
                                        _extractedTextController.text
                                            .toLowerCase();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Editable Text Area
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: TextField(
                            controller: _extractedTextController,
                            maxLines: 12,
                            minLines: 7,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  '1. Upload a photo or take a picture.\n2. Drag the corner brackets to crop the exact paragraph.\n3. Clean, formatted text will appear here automatically!',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13.5,
                                height: 1.6,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),

                        // Bottom Stats Footer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(22),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildStatBadge('$wordCount Words'),
                              const SizedBox(width: 8),
                              _buildStatBadge('$charCount Chars'),
                              const SizedBox(width: 8),
                              _buildStatBadge('$lineCount Lines'),
                              const Spacer(),
                              if (currentText.isNotEmpty)
                                InkWell(
                                  onTap: () {
                                    _extractedTextController.clear();
                                    setState(() {});
                                  },
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangTab(String code, String label) {
    final bool selected = _selectedLang == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedLang = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: isPrimary ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF818CF8).withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextToolChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF475569)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

// ============================================================================
// PRO INTERACTIVE CROP & ROTATE STUDIO (L-BRACKET SCANNER UI)
// ============================================================================
class _ProCropStudioScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const _ProCropStudioScreen({required this.imageBytes});

  @override
  State<_ProCropStudioScreen> createState() => _ProCropStudioScreenState();
}

class _ProCropStudioScreenState extends State<_ProCropStudioScreen> {
  ui.Image? _decodedImage;
  bool _isProcessing = false;

  // Normalized Crop Box (0.0 to 1.0)
  Rect _cropRect = const Rect.fromLTWH(0.08, 0.15, 0.84, 0.65);

  @override
  void initState() {
    super.initState();
    _loadUiImage(widget.imageBytes);
  }

  Future<void> _loadUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _decodedImage = frame.image;
      });
    }
  }

  Future<void> _rotateImage90() async {
    if (_decodedImage == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    final ui.Image src = _decodedImage!;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double newWidth = src.height.toDouble();
    final double newHeight = src.width.toDouble();

    canvas.translate(newWidth, 0);
    canvas.rotate(3.141592653589793 / 2);
    canvas.drawImage(src, Offset.zero, Paint());

    final ui.Picture picture = recorder.endRecording();
    final ui.Image rotated =
        await picture.toImage(newWidth.toInt(), newHeight.toInt());

    if (mounted) {
      setState(() {
        _decodedImage = rotated;
        _cropRect = const Rect.fromLTWH(0.08, 0.15, 0.84, 0.65);
        _isProcessing = false;
      });
    }
  }

  Future<void> _confirmAndCrop() async {
    if (_decodedImage == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final ui.Image src = _decodedImage!;
      final double imgW = src.width.toDouble();
      final double imgH = src.height.toDouble();

      final Rect srcRect = Rect.fromLTWH(
        (_cropRect.left * imgW).clamp(0.0, imgW - 10),
        (_cropRect.top * imgH).clamp(0.0, imgH - 10),
        (_cropRect.width * imgW).clamp(10.0, imgW),
        (_cropRect.height * imgH).clamp(10.0, imgH),
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Rect dstRect = Rect.fromLTWH(0, 0, srcRect.width, srcRect.height);

      canvas.drawImageRect(src, srcRect, dstRect, Paint());

      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedUiImage = await picture.toImage(
        srcRect.width.toInt(),
        srcRect.height.toInt(),
      );

      final ByteData? byteData =
          await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        Navigator.pop(context, byteData.buffer.asUint8List());
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, widget.imageBytes);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Scan Region',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Rotate 90°',
            onPressed: _rotateImage90,
            icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
          ),
          TextButton(
            onPressed: () => setState(
              () => _cropRect = const Rect.fromLTWH(0.02, 0.02, 0.96, 0.96),
            ),
            child: const Text(
              'Select All',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: _decodedImage == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Drag corners or center box to frame the exact paragraph',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double imgAspect =
                            _decodedImage!.width / _decodedImage!.height;
                        final double boxAspect =
                            constraints.maxWidth / constraints.maxHeight;

                        double renderW, renderH;
                        if (imgAspect > boxAspect) {
                          renderW = constraints.maxWidth;
                          renderH = renderW / imgAspect;
                        } else {
                          renderH = constraints.maxHeight;
                          renderW = renderH * imgAspect;
                        }

                        final Rect pixelCrop = Rect.fromLTWH(
                          _cropRect.left * renderW,
                          _cropRect.top * renderH,
                          _cropRect.width * renderW,
                          _cropRect.height * renderH,
                        );

                        return Center(
                          child: SizedBox(
                            width: renderW,
                            height: renderH,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: RawImage(
                                    image: _decodedImage,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _ProScannerOverlayPainter(
                                      cropRect: pixelCrop,
                                    ),
                                  ),
                                ),
                                // Drag Inside Box
                                Positioned.fromRect(
                                  rect: pixelCrop,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanUpdate: (d) {
                                      setState(() {
                                        final double dx = d.delta.dx / renderW;
                                        final double dy = d.delta.dy / renderH;
                                        final double newL = (_cropRect.left + dx)
                                            .clamp(0.0, 1.0 - _cropRect.width);
                                        final double newT = (_cropRect.top + dy)
                                            .clamp(0.0, 1.0 - _cropRect.height);
                                        _cropRect = Rect.fromLTWH(
                                          newL,
                                          newT,
                                          _cropRect.width,
                                          _cropRect.height,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                // 4 Corner Touch Zones
                                _buildTouchCorner(
                                  left: pixelCrop.left - 18,
                                  top: pixelCrop.top - 18,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nl =
                                          (_cropRect.left + d.dx / renderW)
                                              .clamp(0.0, _cropRect.right - 0.12);
                                      final double nt =
                                          (_cropRect.top + d.dy / renderH)
                                              .clamp(0.0, _cropRect.bottom - 0.08);
                                      _cropRect = Rect.fromLTRB(
                                        nl,
                                        nt,
                                        _cropRect.right,
                                        _cropRect.bottom,
                                      );
                                    });
                                  },
                                ),
                                _buildTouchCorner(
                                  left: pixelCrop.right - 18,
                                  top: pixelCrop.top - 18,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nr =
                                          (_cropRect.right + d.dx / renderW)
                                              .clamp(_cropRect.left + 0.12, 1.0);
                                      final double nt =
                                          (_cropRect.top + d.dy / renderH)
                                              .clamp(0.0, _cropRect.bottom - 0.08);
                                      _cropRect = Rect.fromLTRB(
                                        _cropRect.left,
                                        nt,
                                        nr,
                                        _cropRect.bottom,
                                      );
                                    });
                                  },
                                ),
                                _buildTouchCorner(
                                  left: pixelCrop.left - 18,
                                  top: pixelCrop.bottom - 18,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nl =
                                          (_cropRect.left + d.dx / renderW)
                                              .clamp(0.0, _cropRect.right - 0.12);
                                      final double nb =
                                          (_cropRect.bottom + d.dy / renderH)
                                              .clamp(_cropRect.top + 0.08, 1.0);
                                      _cropRect = Rect.fromLTRB(
                                        nl,
                                        _cropRect.top,
                                        _cropRect.right,
                                        nb,
                                      );
                                    });
                                  },
                                ),
                                _buildTouchCorner(
                                  left: pixelCrop.right - 18,
                                  top: pixelCrop.bottom - 18,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nr =
                                          (_cropRect.right + d.dx / renderW)
                                              .clamp(_cropRect.left + 0.12, 1.0);
                                      final double nb =
                                          (_cropRect.bottom + d.dy / renderH)
                                              .clamp(_cropRect.top + 0.08, 1.0);
                                      _cropRect = Rect.fromLTRB(
                                        _cropRect.left,
                                        _cropRect.top,
                                        nr,
                                        nb,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Bottom Controls
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetBtn(
                              'Full Page',
                              const Rect.fromLTWH(0.03, 0.03, 0.94, 0.94),
                            ),
                            const SizedBox(width: 8),
                            _buildPresetBtn(
                              'Paragraph Block',
                              const Rect.fromLTWH(0.06, 0.22, 0.88, 0.52),
                            ),
                            const SizedBox(width: 8),
                            _buildPresetBtn(
                              'Single Line / Heading',
                              const Rect.fromLTWH(0.06, 0.42, 0.88, 0.15),
                            ),
                            const SizedBox(width: 8),
                            _buildPresetBtn(
                              'Top Half',
                              const Rect.fromLTWH(0.04, 0.04, 0.92, 0.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isProcessing ? null : _confirmAndCrop,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.document_scanner_rounded),
                          label: const Text(
                            'Crop & Extract Text',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
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

  Widget _buildTouchCorner({
    required double left,
    required double top,
    required void Function(Offset delta) onDrag,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onDrag(d.delta),
        child: const SizedBox(width: 36, height: 36),
      ),
    );
  }

  Widget _buildPresetBtn(String label, Rect rect) {
    return ActionChip(
      backgroundColor: const Color(0xFF1F2937),
      side: const BorderSide(color: Color(0xFF374151)),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: () => setState(() => _cropRect = rect),
    );
  }
}

class _ProScannerOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _ProScannerOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final Path fullPath = Path()..addRect(Offset.zero & size);
    final Path holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(6)));

    final Path overlayPath =
        Path.combine(PathOperation.difference, fullPath, holePath);

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withOpacity(0.68),
    );

    // Subtle Inner Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(6)),
      Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Rule of Thirds Grid
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1;

    final double thirdW = cropRect.width / 3;
    final double thirdH = cropRect.height / 3;

    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        gridPaint,
      );
    }

    // Pro L-Shaped Corner Brackets
    final Paint bracketPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double len = 22.0;
    final double l = cropRect.left;
    final double t = cropRect.top;
    final double r = cropRect.right;
    final double b = cropRect.bottom;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t)
        ..lineTo(l + len, t),
      bracketPaint,
    );
    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(r - len, t)
        ..lineTo(r, t)
        ..lineTo(r, t + len),
      bracketPaint,
    );
    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(l, b - len)
        ..lineTo(l, b)
        ..lineTo(l + len, b),
      bracketPaint,
    );
    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(r - len, b)
        ..lineTo(r, b)
        ..lineTo(r, b - len),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProScannerOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}