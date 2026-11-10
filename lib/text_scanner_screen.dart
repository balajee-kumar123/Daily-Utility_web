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
  final String _ocrApiKey =
      dotenv.env['OCR_API_KEY'] ??
      dotenv.env['OCR_SPACE_API_KEY'] ??
      'helloworld';

  Uint8List? _originalImageBytes;
  Uint8List? _croppedImageBytes;
  bool _isScanning = false;
  bool _isSpeaking = false;
  String _selectedLang = 'eng'; // 'eng' = English, 'hin' = Hindi

  final TextEditingController _extractedTextController =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();

  double _speechRate = 0.5;
  double _pitch = 1.0;

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

  Future<void> _pickImageAndOpenCropper(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      final Uint8List rawBytes = await pickedFile.readAsBytes();
      setState(() {
        _originalImageBytes = rawBytes;
      });

      if (!mounted) return;
      await _openCropStudio(rawBytes);
    } catch (e) {
      _showSnack('Could not pick image: $e');
    }
  }

  Future<void> _openCropStudio(Uint8List sourceBytes) async {
    final Uint8List? croppedResult = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => _SmartImageCropStudio(imageBytes: sourceBytes),
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

      final response = await http.post(
        Uri.parse('https://api.ocr.space/parse/image'),
        headers: {'apikey': _ocrApiKey.trim()},
        body: {
          'base64Image': base64Image,
          'language': _selectedLang,
          'isOverlayRequired': 'false',
          'scale': 'true',
          'OCREngine': '2',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List? parsedResults = data['ParsedResults'];

        if (parsedResults != null && parsedResults.isNotEmpty) {
          final String text = (parsedResults[0]['ParsedText'] ?? '')
              .toString()
              .trim();

          setState(() {
            _extractedTextController.text = text.isEmpty
                ? 'No readable text found in selected area. Try adjusting the crop box!'
                : text;
          });
        } else {
          final String err = (data['ErrorMessage'] ?? 'Unable to extract text.')
              .toString();
          _showSnack(err);
        }
      } else {
        _showSnack('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('Network error while scanning text.');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _toggleVoiceReader() async {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) {
      _showSnack('No text to read! Scan an image or type something first.');
      return;
    }

    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      await _flutterTts.setLanguage(_selectedLang == 'hin' ? 'hi-IN' : 'en-IN');
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
    }
  }

  void _copyText() {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Text copied to clipboard!');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int wordCount = _extractedTextController.text.trim().isEmpty
        ? 0
        : _extractedTextController.text.trim().split(RegExp(r'\s+')).length;
    final int charCount = _extractedTextController.text.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Smart OCR & Crop Studio',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (_croppedImageBytes != null ||
              _extractedTextController.text.isNotEmpty)
            IconButton(
              tooltip: 'Reset All',
              onPressed: () {
                _flutterTts.stop();
                setState(() {
                  _originalImageBytes = null;
                  _croppedImageBytes = null;
                  _extractedTextController.clear();
                  _isSpeaking = false;
                });
              },
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Color(0xFFEF4444),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Language & Image Picker Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.translate_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'OCR Language:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const Spacer(),
                      ChoiceChip(
                        showCheckmark: false,
                        label: const Text('English'),
                        selected: _selectedLang == 'eng',
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: _selectedLang == 'eng'
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedLang = 'eng'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        showCheckmark: false,
                        label: const Text('Hindi (हिंदी)'),
                        selected: _selectedLang == 'hin',
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: _selectedLang == 'hin'
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedLang = 'hin'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isScanning
                              ? null
                              : () => _pickImageAndOpenCropper(
                                  ImageSource.gallery,
                                ),
                          icon: const Icon(
                            Icons.photo_library_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'Gallery & Crop',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isScanning
                              ? null
                              : () => _pickImageAndOpenCropper(
                                  ImageSource.camera,
                                ),
                          icon: const Icon(Icons.camera_alt_rounded, size: 20),
                          label: const Text(
                            'Camera & Crop',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Cropped Image Preview + Re-Crop & Re-Scan Controls
            if (_croppedImageBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'CROPPED SELECTION',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_originalImageBytes != null)
                          TextButton.icon(
                            onPressed: _isScanning
                                ? null
                                : () => _openCropStudio(_originalImageBytes!),
                            icon: const Icon(
                              Icons.crop_rotate_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Adjust Crop Area',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 190),
                        color: const Color(0xFFF1F5F9),
                        child: Image.memory(
                          _croppedImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (_isScanning) ...[
                      const SizedBox(height: 14),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Extracting text from cropped area...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _performOcr(_croppedImageBytes!),
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Re-Scan Selection'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // 3. AI Voice Reader (TTS) Studio Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isSpeaking
                              ? Icons.graphic_eq_rounded
                              : Icons.record_voice_over_rounded,
                          color: const Color(0xFF60A5FA),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Voice Reader (TTS)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                            ),
                            Text(
                              'Listen to cropped text or pasted notes aloud',
                              style: TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSpeaking
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _toggleVoiceReader,
                        icon: Icon(
                          _isSpeaking
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          _isSpeaking ? 'Stop' : 'Listen',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Speed:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: _speechRate,
                          min: 0.2,
                          max: 1.0,
                          activeColor: const Color(0xFF60A5FA),
                          inactiveColor: Colors.white24,
                          onChanged: (val) => setState(() => _speechRate = val),
                        ),
                      ),
                      Text(
                        '${(_speechRate * 2).toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Extracted / Editable Text Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Extracted / Editable Text',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: _copyText,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          'Copy Text',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  TextField(
                    controller: _extractedTextController,
                    maxLines: 10,
                    minLines: 6,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Pick an image -> Drag the corners to crop the exact paragraph or formula -> Extracted text will appear here!',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$wordCount words • $charCount characters',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _extractedTextController.clear();
                          setState(() {});
                        },
                        child: const Text(
                          'Clear Text',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BUILT-IN INTERACTIVE CROP & ROTATE STUDIO (WEB + ANDROID COMPATIBLE)
// ============================================================================
class _SmartImageCropStudio extends StatefulWidget {
  final Uint8List imageBytes;

  const _SmartImageCropStudio({required this.imageBytes});

  @override
  State<_SmartImageCropStudio> createState() => _SmartImageCropStudioState();
}

class _SmartImageCropStudioState extends State<_SmartImageCropStudio> {
  ui.Image? _decodedImage;
  bool _isProcessing = false;

  // Normalized Crop Box Coordinates (0.0 to 1.0 relative to displayed image)
  Rect _cropRect = const Rect.fromLTWH(0.1, 0.15, 0.8, 0.7);

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

  // Rotate image 90 degrees clockwise on canvas
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
    final ui.Image rotated = await picture.toImage(
      newWidth.toInt(),
      newHeight.toInt(),
    );

    if (mounted) {
      setState(() {
        _decodedImage = rotated;
        _cropRect = const Rect.fromLTWH(0.1, 0.15, 0.8, 0.7);
        _isProcessing = false;
      });
    }
  }

  // Crop selected normalized rectangle from actual high-res image
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

      final ByteData? byteData = await croppedUiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null && mounted) {
        Navigator.pop(context, byteData.buffer.asUint8List());
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, widget.imageBytes);
      }
    }
  }

  void _setPresetCrop(Rect preset) {
    setState(() => _cropRect = preset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'Crop Text Area',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: _rotateImage90,
            icon: const Icon(
              Icons.rotate_90_degrees_cw_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Rotate',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                _setPresetCrop(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)),
            child: const Text(
              'Full Image',
              style: TextStyle(
                color: Color(0xFF60A5FA),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _decodedImage == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Drag the blue corners or inside the box to select the exact lines you want to scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                                // Base Image
                                Positioned.fill(
                                  child: RawImage(
                                    image: _decodedImage,
                                    fit: BoxFit.fill,
                                  ),
                                ),

                                // Dark Overlay + Grid Lines Painter
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _CropOverlayPainter(
                                      cropRect: pixelCrop,
                                    ),
                                  ),
                                ),

                                // Center Drag Area (Move entire crop box)
                                Positioned.fromRect(
                                  rect: pixelCrop,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanUpdate: (d) {
                                      setState(() {
                                        final double dx = d.delta.dx / renderW;
                                        final double dy = d.delta.dy / renderH;
                                        final double newL =
                                            (_cropRect.left + dx).clamp(
                                              0.0,
                                              1.0 - _cropRect.width,
                                            );
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

                                // 4 Draggable Corner Handles
                                _buildCornerHandle(
                                  left: pixelCrop.left - 14,
                                  top: pixelCrop.top - 14,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nl =
                                          (_cropRect.left + d.dx / renderW)
                                              .clamp(
                                                0.0,
                                                _cropRect.right - 0.12,
                                              );
                                      final double nt =
                                          (_cropRect.top + d.dy / renderH)
                                              .clamp(
                                                0.0,
                                                _cropRect.bottom - 0.10,
                                              );
                                      _cropRect = Rect.fromLTRB(
                                        nl,
                                        nt,
                                        _cropRect.right,
                                        _cropRect.bottom,
                                      );
                                    });
                                  },
                                ),
                                _buildCornerHandle(
                                  left: pixelCrop.right - 14,
                                  top: pixelCrop.top - 14,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nr =
                                          (_cropRect.right + d.dx / renderW)
                                              .clamp(
                                                _cropRect.left + 0.12,
                                                1.0,
                                              );
                                      final double nt =
                                          (_cropRect.top + d.dy / renderH)
                                              .clamp(
                                                0.0,
                                                _cropRect.bottom - 0.10,
                                              );
                                      _cropRect = Rect.fromLTRB(
                                        _cropRect.left,
                                        nt,
                                        nr,
                                        _cropRect.bottom,
                                      );
                                    });
                                  },
                                ),
                                _buildCornerHandle(
                                  left: pixelCrop.left - 14,
                                  top: pixelCrop.bottom - 14,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nl =
                                          (_cropRect.left + d.dx / renderW)
                                              .clamp(
                                                0.0,
                                                _cropRect.right - 0.12,
                                              );
                                      final double nb =
                                          (_cropRect.bottom + d.dy / renderH)
                                              .clamp(_cropRect.top + 0.10, 1.0);
                                      _cropRect = Rect.fromLTRB(
                                        nl,
                                        _cropRect.top,
                                        _cropRect.right,
                                        nb,
                                      );
                                    });
                                  },
                                ),
                                _buildCornerHandle(
                                  left: pixelCrop.right - 14,
                                  top: pixelCrop.bottom - 14,
                                  onDrag: (d) {
                                    setState(() {
                                      final double nr =
                                          (_cropRect.right + d.dx / renderW)
                                              .clamp(
                                                _cropRect.left + 0.12,
                                                1.0,
                                              );
                                      final double nb =
                                          (_cropRect.bottom + d.dy / renderH)
                                              .clamp(_cropRect.top + 0.10, 1.0);
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

                // Quick Crop Presets & Confirm Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip(
                              'Full Page',
                              const Rect.fromLTWH(0.03, 0.03, 0.94, 0.94),
                            ),
                            const SizedBox(width: 8),
                            _buildPresetChip(
                              'Center Paragraph',
                              const Rect.fromLTWH(0.08, 0.25, 0.84, 0.50),
                            ),
                            const SizedBox(width: 8),
                            _buildPresetChip(
                              'Single Line / Strip',
                              const Rect.fromLTWH(0.08, 0.40, 0.84, 0.18),
                            ),
                            const SizedBox(width: 8),
                            _buildPresetChip(
                              'Top Half',
                              const Rect.fromLTWH(0.05, 0.05, 0.90, 0.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                              : const Icon(Icons.crop_rounded),
                          label: const Text(
                            'Crop & Extract Text Now',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
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

  Widget _buildCornerHandle({
    required double left,
    required double top,
    required void Function(Offset delta) onDrag,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (d) => onDrag(d.delta),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, Rect rect) {
    return ActionChip(
      backgroundColor: const Color(0xFF334155),
      side: BorderSide.none,
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _setPresetCrop(rect),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final Path fullPath = Path()..addRect(Offset.zero & size);
    final Path holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(8)));

    final Path overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      holePath,
    );

    // Darken outside area
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withOpacity(0.62),
    );

    // Bright border around selected area
    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(8)),
      Paint()
        ..color = const Color(0xFF60A5FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Rule of thirds helper grid lines inside crop box
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
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
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
