import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

class ImageResizerScreen extends StatefulWidget {
  const ImageResizerScreen({super.key});

  @override
  State<ImageResizerScreen> createState() => _ImageResizerScreenState();
}

class _ImageResizerScreenState extends State<ImageResizerScreen> {
  Uint8List? _originalBytes;
  Uint8List? _resizedBytes;

  int? _origWidth;
  int? _origHeight;
  double? _origSizeKb;
  double? _newSizeKb;
  int _usedQuality = 85;

  final TextEditingController _widthController = TextEditingController(
    text: '350',
  );
  final TextEditingController _heightController = TextEditingController(
    text: '450',
  );
  final TextEditingController _targetKbController = TextEditingController(
    text: '50',
  );

  bool _lockAspectRatio = false;
  bool _useTargetKb = true; // डिफ़ॉल्ट रूप से Target KB मोड ऑन रहेगा
  double _manualQuality = 80;
  bool _isProcessing = false;

  final ImagePicker _picker = ImagePicker();

  // 1. फोटो चुनना
  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();

      setState(() {
        _originalBytes = bytes;
        _origWidth = frame.image.width;
        _origHeight = frame.image.height;
        _origSizeKb = bytes.lengthInBytes / 1024;
        // अगर बहुत बड़ी फोटो है तो डिफ़ॉल्ट रूप से थोड़ा छोटा साइज दिखाएं
        _widthController.text =
            (frame.image.width > 800 ? 600 : frame.image.width).toString();
        _heightController.text =
            (frame.image.height > 800 ? 750 : frame.image.height).toString();
        _resizedBytes = null;
        _newSizeKb = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('फोटो लोड करने में एरर: $e')));
    }
  }

  // Aspect Ratio के हिसाब से Height ऑटो-कैलकुलेट करना
  void _onWidthChanged(String val) {
    if (!_lockAspectRatio || _origWidth == null || _origHeight == null) return;
    final int? w = int.tryParse(val);
    if (w != null && w > 0) {
      final int newH = ((w * _origHeight!) / _origWidth!).round();
      _heightController.text = newH.toString();
    }
  }

  // 2. स्मार्ट रिसाइज + Target KB Auto-Compressor
  Future<void> _resizeAndMatchKb() async {
    if (_originalBytes == null) return;

    int? targetW = int.tryParse(_widthController.text.trim());
    int? targetH = int.tryParse(_heightController.text.trim());
    final double? maxKb = double.tryParse(_targetKbController.text.trim());

    if (targetW == null || targetH == null || targetW <= 0 || targetH <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया सही Width और Height डालें!')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // स्टेप A: पहले Flutter के फास्ट इंजन से इमेज को छोटे पिक्सल में बदलना (ताकि हैंग न हो)
      final ui.Codec codec = await ui.instantiateImageCodec(
        _originalBytes!,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? rawRgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (rawRgba == null) throw Exception('Image conversion failed');

      // स्टेप B: छोटे साइज की इमेज को JPG में बदलना
      img.Image baseImage = img.Image.fromBytes(
        width: frame.image.width,
        height: frame.image.height,
        bytes: rawRgba.buffer,
        numChannels: 4,
      );

      Uint8List finalJpg;
      int appliedQuality = _manualQuality.toInt();

      if (_useTargetKb && maxKb != null && maxKb > 5) {
        // 🎯 Auto KB Matching Loop: जब तक टारगेट KB के अंदर न आ जाए, क्वालिटी एडजस्ट करेगा
        int q = 92;
        finalJpg = Uint8List.fromList(img.encodeJpg(baseImage, quality: q));

        while ((finalJpg.lengthInBytes / 1024) > maxKb && q > 10) {
          q -= 8;
          finalJpg = Uint8List.fromList(img.encodeJpg(baseImage, quality: q));
        }

        // अगर क्वालिटी 10% करने पर भी KB ज्यादा है, तो डाइमेंशन थोड़ा और छोटा कर देगा
        while ((finalJpg.lengthInBytes / 1024) > maxKb &&
            baseImage.width > 120) {
          baseImage = img.copyResize(
            baseImage,
            width: (baseImage.width * 0.8).round(),
            height: (baseImage.height * 0.8).round(),
          );
          finalJpg = Uint8List.fromList(img.encodeJpg(baseImage, quality: 25));
        }
        appliedQuality = q < 10 ? 10 : q;
      } else {
        // मैनुअल स्लाइडर मोड
        finalJpg = Uint8List.fromList(
          img.encodeJpg(baseImage, quality: appliedQuality),
        );
      }

      setState(() {
        _resizedBytes = finalJpg;
        _newSizeKb = finalJpg.lengthInBytes / 1024;
        _usedQuality = appliedQuality;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('रिसाइज एरर: $e')));
    }
  }

  // 3. JPG फाइल डाउनलोड या शेयर करना
  Future<void> _downloadImage() async {
    if (_resizedBytes == null) return;
    try {
      final String fileName = 'balajee_resized_${_newSizeKb!.toInt()}kb.jpg';
      final XFile xFile = XFile.fromData(
        _resizedBytes!,
        mimeType: 'image/jpeg',
        name: fileName,
      );

      if (kIsWeb) {
        await xFile.saveTo(fileName);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅ $fileName डाउनलोड हो गई!')));
      } else {
        await Share.shareXFiles([
          xFile,
        ], text: 'Resized Image (${_newSizeKb!.toStringAsFixed(1)} KB)');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('डाउनलोड एरर: $e')));
    }
  }

  // फॉर्म के लिए 1-क्लिक प्रीसेट (Size + Target KB एक साथ!)
  void _applySmartPreset({required int w, required int h, required int maxKb}) {
    setState(() {
      _widthController.text = w.toString();
      _heightController.text = h.toString();
      _targetKbController.text = maxKb.toString();
      _useTargetKb = true;
    });
    _resizeAndMatchKb();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text('Smart KB & Size Resizer'),
        backgroundColor: Colors.pink.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Pick Image Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text(
                '1. गैलरी से फोटो चुनें (Select Photo)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            if (_originalBytes != null) ...[
              // Original Image Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _originalBytes!,
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'असली फोटो: $_origWidth x $_origHeight px  |  ${_origSizeKb!.toStringAsFixed(1)} KB',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Smart Settings Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚡ Online Form 1-Click Presets:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.pink,
                          ),
                          label: const Text('Passport (350x450 • <50KB)'),
                          onPressed: () =>
                              _applySmartPreset(w: 350, h: 450, maxKb: 48),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.draw,
                            size: 16,
                            color: Colors.indigo,
                          ),
                          label: const Text('Signature (300x120 • <20KB)'),
                          onPressed: () =>
                              _applySmartPreset(w: 300, h: 120, maxKb: 18),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.badge,
                            size: 16,
                            color: Colors.teal,
                          ),
                          label: const Text('SSC/Govt Photo (<40KB)'),
                          onPressed: () =>
                              _applySmartPreset(w: 320, h: 400, maxKb: 38),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.hd,
                            size: 16,
                            color: Colors.orange,
                          ),
                          label: const Text('Under 100 KB'),
                          onPressed: () =>
                              _applySmartPreset(w: 600, h: 600, maxKb: 95),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Width & Height + Aspect Ratio Lock
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📐 कस्टम साइज (Width x Height):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _lockAspectRatio,
                              activeColor: Colors.pink.shade700,
                              onChanged: (val) => setState(
                                () => _lockAspectRatio = val ?? false,
                              ),
                            ),
                            const Text(
                              'Lock Ratio',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            keyboardType: TextInputType.number,
                            onChanged: _onWidthChanged,
                            decoration: InputDecoration(
                              labelText: 'Width (px)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Height (px)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // 🎯 Target KB Mode Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.pink.shade700,
                      title: const Text(
                        '🎯 फिक्स KB टारगेट सेट करें (Target KB)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'फोटो आपके लिखे हुए KB से कम साइज में ही बनेगी',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _useTargetKb,
                      onChanged: (val) => setState(() => _useTargetKb = val),
                    ),

                    if (_useTargetKb) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _targetKbController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'अधिकतम कितने KB चाहिए? (e.g. 50)',
                                suffixText: 'KB',
                                prefixIcon: const Icon(
                                  Icons.compress,
                                  color: Colors.pink,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [20, 30, 50, 100, 200].map((kb) {
                          return ChoiceChip(
                            label: Text('Max $kb KB'),
                            selected: _targetKbController.text == kb.toString(),
                            selectedColor: Colors.pink.shade100,
                            onSelected: (_) {
                              setState(
                                () => _targetKbController.text = kb.toString(),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Text(
                        'Manual Quality: ${_manualQuality.toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: _manualQuality,
                        min: 10,
                        max: 100,
                        divisions: 18,
                        activeColor: Colors.pink.shade700,
                        onChanged: (val) =>
                            setState(() => _manualQuality = val),
                      ),
                    ],

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isProcessing ? null : _resizeAndMatchKb,
                        icon: const Icon(Icons.auto_fix_high),
                        label: Text(
                          _isProcessing
                              ? 'KB सेट हो रहा है...'
                              : '2. Resize & Match KB Now',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 3. Output Result Card
            if (_resizedBytes != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade400, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      '✅ आपकी फोटो तैयार है! (JPG Format)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _resizedBytes!,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'नया फाइल साइज: ${_newSizeKb!.toStringAsFixed(1)} KB',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'पहले: ${_origSizeKb!.toStringAsFixed(1)} KB था  •  Quality: $_usedQuality%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _downloadImage,
                        icon: const Icon(Icons.download),
                        label: const Text(
                          '3. Download / Save JPG',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
}
