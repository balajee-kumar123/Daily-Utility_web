import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReceivedFileItem {
  final String name;
  final Uint8List bytes;
  final DateTime time;

  ReceivedFileItem({
    required this.name,
    required this.bytes,
    required this.time,
  });

  String get sizeText {
    final kb = bytes.lengthInBytes / 1024;
    return kb < 1024
        ? '${kb.toStringAsFixed(1)} KB'
        : '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  String get timeText =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

  bool get isImage {
    final l = name.toLowerCase();
    return l.endsWith('.png') ||
        l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.gif') ||
        l.endsWith('.webp');
  }
}

class ReceivedTextItem {
  final String text;
  final DateTime time;

  ReceivedTextItem({required this.text, required this.time});

  String get timeText =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class WifiDropScreen extends StatefulWidget {
  const WifiDropScreen({super.key});

  @override
  State<WifiDropScreen> createState() => _WifiDropScreenState();
}

class _WifiDropScreenState extends State<WifiDropScreen> {
  HttpServer? _server;
  String _localIp = 'Checking IP...';
  final int _port = 8085;
  bool _isRunning = false;
  int _activeTab = 0;

  bool _requirePin = false;
  String _securityPin = '1234';

  final TextEditingController _textController = TextEditingController();
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _selectedFilePath;
  int _selectedFileSize = 0;

  final List<ReceivedTextItem> _receivedMessages = [];
  final List<ReceivedFileItem> _receivedFiles = [];
  int _totalTransfers = 0;

  @override
  void initState() {
    super.initState();
    _generateRandomPin();
    _fetchLocalIp();
  }

  @override
  void dispose() {
    _stopServer();
    _textController.dispose();
    super.dispose();
  }

  void _generateRandomPin() {
    _securityPin = (1000 + Random().nextInt(9000)).toString();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final kb = bytes / 1024;
    return kb < 1024
        ? '${kb.toStringAsFixed(1)} KB'
        : '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  Future<void> _fetchLocalIp() async {
    if (kIsWeb) {
      setState(() => _localIp = 'Run on Windows/Android');
      return;
    }
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            setState(() => _localIp = addr.address);
            return;
          }
        }
      }
      setState(
        () => _localIp =
            interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty
            ? interfaces.first.addresses.first.address
            : '127.0.0.1',
      );
    } catch (_) {
      setState(() => _localIp = '127.0.0.1');
    }
  }

  // GEMINI-STYLE NATIVE ATTACHMENT SHEET
  void _openGeminiStylePickerMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share from Device',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _GeminiOptionTile(
                    icon: Icons.photo_library_rounded,
                    color: Colors.purpleAccent,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickNativeFile(fp.FileType.media);
                    },
                  ),
                  _GeminiOptionTile(
                    icon: Icons.image_rounded,
                    color: Colors.blueAccent,
                    label: 'Photos',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickNativeFile(fp.FileType.image);
                    },
                  ),
                  _GeminiOptionTile(
                    icon: Icons.picture_as_pdf_rounded,
                    color: Colors.orangeAccent,
                    label: 'Documents',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickNativeFile(
                        fp.FileType.custom,
                        extensions: [
                          'pdf',
                          'doc',
                          'docx',
                          'ppt',
                          'pptx',
                          'xls',
                          'xlsx',
                          'txt',
                          'zip',
                        ],
                      );
                    },
                  ),
                  _GeminiOptionTile(
                    icon: Icons.folder_rounded,
                    color: Colors.teal,
                    label: 'All Files',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickNativeFile(fp.FileType.any);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // EXACT MATCH FOR file_picker-13.2.0: static Future<List<PlatformFile>> pickFiles
  // EXACT MATCH FOR file_picker-13.2.0 (Uses only picked.name & picked.path)
  Future<void> _pickNativeFile(
    fp.FileType type, {
    List<String>? extensions,
  }) async {
    try {
      final List<fp.PlatformFile> files = await fp.FilePicker.pickFiles(
        type: type,
        allowedExtensions: extensions,
      );

      if (files.isNotEmpty) {
        final fp.PlatformFile picked = files.first;
        Uint8List? bytes;
        int fileSize = 0;

        if (!kIsWeb && picked.path != null) {
          final file = File(picked.path!);
          if (await file.exists()) {
            fileSize = await file.length();
            if (fileSize < 30 * 1024 * 1024) {
              bytes = await file.readAsBytes();
            }
          }
        }

        setState(() {
          _selectedFileName = picked.name;
          _selectedFileBytes = bytes;
          _selectedFilePath = picked.path;
          _selectedFileSize = fileSize;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Attached: ${picked.name} (${_formatBytes(fileSize)})',
              ),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open picker: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _shareTextAsFile() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle text box mein kuch type karein!')),
      );
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(_textController.text));
    setState(() {
      _selectedFileName = 'shared_snippet.txt';
      _selectedFileBytes = bytes;
      _selectedFilePath = null;
      _selectedFileSize = bytes.lengthInBytes;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ready to download as shared_snippet.txt!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Future<void> _toggleServer() async {
    if (_isRunning) {
      await _stopServer();
      return;
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Server ke liye app ko Android ya Windows par run karein!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      await _fetchLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      setState(() => _isRunning = true);

      _server!.listen((HttpRequest request) async {
        try {
          final reqPin = request.uri.queryParameters['pin'] ?? '';
          if (request.method == 'GET' && request.uri.path == '/download') {
            if (_requirePin && reqPin != _securityPin) {
              request.response.statusCode = HttpStatus.forbidden;
              request.response.write('Invalid Security PIN!');
              await request.response.close();
              return;
            }
            if (_selectedFileName != null) {
              request.response.headers.contentType = ContentType.binary;
              request.response.headers.add(
                'Content-Disposition',
                'attachment; filename="${Uri.encodeComponent(_selectedFileName!)}"',
              );
              if (_selectedFileBytes != null) {
                request.response.contentLength = _selectedFileBytes!.length;
                request.response.add(_selectedFileBytes!);
              } else if (_selectedFilePath != null) {
                final file = File(_selectedFilePath!);
                request.response.contentLength = await file.length();
                await request.response.addStream(file.openRead());
              }
              setState(() => _totalTransfers++);
              await request.response.close();
            } else {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write('No file attached.');
              await request.response.close();
            }
          } else if (request.method == 'POST' && request.uri.path == '/send') {
            final content = await utf8.decoder.bind(request).join();
            final params = Uri.splitQueryString(content);
            if (_requirePin && (params['pin'] ?? '') != _securityPin) {
              request.response.statusCode = HttpStatus.forbidden;
              await request.response.close();
              return;
            }
            final msg = params['msg'] ?? '';
            if (msg.trim().isNotEmpty) {
              setState(() {
                _receivedMessages.insert(
                  0,
                  ReceivedTextItem(text: msg.trim(), time: DateTime.now()),
                );
                _totalTransfers++;
                _activeTab = 1;
              });
            }
            request.response.statusCode = HttpStatus.found;
            request.response.headers.set('Location', '/');
            await request.response.close();
          } else if (request.method == 'POST' &&
              request.uri.path == '/upload') {
            final content = await utf8.decoder.bind(request).join();
            final data = jsonDecode(content) as Map<String, dynamic>;
            if (_requirePin && (data['pin'] ?? '').toString() != _securityPin) {
              request.response.statusCode = HttpStatus.forbidden;
              await request.response.close();
              return;
            }
            final fileName = (data['name'] ?? 'file.bin').toString();
            final base64Str = (data['data'] ?? '').toString();
            if (base64Str.isNotEmpty) {
              setState(() {
                _receivedFiles.insert(
                  0,
                  ReceivedFileItem(
                    name: fileName,
                    bytes: base64Decode(base64Str),
                    time: DateTime.now(),
                  ),
                );
                _totalTransfers++;
                _activeTab = 1;
              });
            }
            request.response.statusCode = HttpStatus.ok;
            request.response.write('OK');
            await request.response.close();
          } else {
            request.response.headers.contentType = ContentType.html;
            request.response.write(_buildPortalHtml());
            await request.response.close();
          }
        } catch (_) {
          await request.response.close();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _stopServer() async {
    await _server?.close(force: true);
    _server = null;
    if (mounted) setState(() => _isRunning = false);
  }

  Future<void> _saveReceivedFile(ReceivedFileItem item) async {
    if (kIsWeb) return;
    try {
      String? dirPath;
      if (Platform.isWindows) {
        final p = Platform.environment['USERPROFILE'];
        if (p != null) dirPath = '$p\\Downloads';
      } else if (Platform.isAndroid) {
        dirPath = '/storage/emulated/0/Download';
      }
      Directory targetDir = Directory(dirPath ?? Directory.systemTemp.path);
      if (!targetDir.existsSync()) targetDir = Directory.systemTemp;
      final savePath = '${targetDir.path}${Platform.pathSeparator}${item.name}';
      await File(savePath).writeAsBytes(item.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $savePath'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _buildPortalHtml() {
    final safeText = const HtmlEscape().convert(_textController.text);
    final hasFile = _selectedFileName != null;
    final sizeStr = _formatBytes(_selectedFileSize);
    final pinHtml = _requirePin
        ? '<input type="password" id="pinBox" placeholder="🔒 Enter 4-Digit PIN" style="width:100%;box-sizing:border-box;background:#0f172a;color:#38bdf8;border:1px solid #38bdf8;border-radius:10px;padding:11px;margin-bottom:14px;text-align:center;">'
        : '<input type="hidden" id="pinBox" value="">';
    final fileSection = hasFile
        ? '<div style="background:#0f172a;padding:14px;border-radius:12px;border:1px solid #10b981;display:flex;justify-content:space-between;align-items:center;margin-top:14px;"><div><b style="color:#34d399;">📁 $_selectedFileName</b><div style="font-size:12px;color:#94a3b8;">$sizeStr</div></div><button onclick="dl()" style="background:#10b981;color:white;border:none;padding:10px 16px;border-radius:10px;font-weight:bold;cursor:pointer;">⬇ Download</button></div>'
        : '';

    return '''<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Wi-Fi Drop Pro</title>
<style>body{font-family:system-ui,sans-serif;background:#0b1120;color:#f8fafc;padding:20px;max-width:740px;margin:auto;}.card{background:#1e293b;padding:20px;border-radius:16px;border:1px solid #334155;margin-bottom:18px;}h3{margin-top:0;color:#38bdf8;}pre{background:#0f172a;padding:14px;border-radius:12px;overflow-x:auto;border:1px solid #334155;white-space:pre-wrap;}button{background:#4f46e5;color:white;border:none;padding:10px 18px;border-radius:10px;font-weight:bold;cursor:pointer;}textarea{width:100%;box-sizing:border-box;background:#0f172a;color:white;border:1px solid #334155;border-radius:10px;padding:12px;min-height:90px;margin-bottom:10px;}.drop{border:2px dashed #475569;border-radius:12px;padding:22px;text-align:center;background:#0f172a;cursor:pointer;margin-bottom:12px;}</style></head>
<body><h2>⚡ Wi-Fi Drop Pro</h2>$pinHtml
<div class="card"><h3>📥 Shared from App</h3><pre id="box">${safeText.isEmpty ? '// No text shared yet.' : safeText}</pre><button onclick="navigator.clipboard.writeText(document.getElementById('box').innerText)">Copy Text</button><button onclick="location.reload()" style="background:#334155;margin-left:8px;">Refresh</button>$fileSection</div>
<div class="card"><h3>📁 Send File to App</h3><div class="drop" onclick="document.getElementById('f').click()"><span id="fl">Tap to select file</span><input type="file" id="f" style="display:none" onchange="document.getElementById('fl').innerText=this.files[0].name"></div><button onclick="up()" style="background:#10b981;">Upload 🚀</button><div id="st" style="margin-top:8px;color:#34d399;"></div></div>
<div class="card"><h3>💬 Send Text to App</h3><textarea id="mb" placeholder="Paste text/code..."></textarea><button onclick="stxt()">Send Text 🚀</button></div>
<script>
function dl(){window.location.href='/download?pin='+encodeURIComponent(document.getElementById('pinBox').value);}
async function stxt(){const m=document.getElementById('mb').value;const p=document.getElementById('pinBox').value;if(!m.trim())return;const r=await fetch('/send',{method:'POST',body:'msg='+encodeURIComponent(m)+'&pin='+encodeURIComponent(p)});if(r.status===403)return alert('Invalid PIN!');document.getElementById('mb').value='';alert('Sent!');}
function up(){const f=document.getElementById('f').files[0];const p=document.getElementById('pinBox').value;const s=document.getElementById('st');if(!f)return alert('Select file!');s.innerText='Uploading...';const r=new FileReader();r.onload=async function(e){const res=await fetch('/upload',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:f.name,data:e.target.result.split(',')[1],pin:p})});s.innerText=res.ok?'✅ Sent!':'❌ Failed';};r.readAsDataURL(f);}
</script></body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final serverUrl = 'http://$_localIp:$_port';
    final totalInbox = _receivedFiles.length + _receivedMessages.length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Wi-Fi Drop Pro',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: textColor,
          ),
        ),
        actions: [
          FilterChip(
            selected: _requirePin,
            label: Text(
              _requirePin ? 'PIN: $_securityPin' : 'PIN Lock',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onSelected: (v) => setState(() {
              _requirePin = v;
              if (v) _generateRandomPin();
            }),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor),
            onPressed: _fetchLocalIp,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SERVER CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isRunning
                          ? [const Color(0xFF059669), const Color(0xFF0D9488)]
                          : [const Color(0xFF4F46E5), const Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isRunning
                                ? Icons.wifi_tethering_rounded
                                : Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isRunning
                                      ? 'SERVER ONLINE ($_totalTransfers)'
                                      : 'OFFLINE READY',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    serverUrl,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: serverUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link Copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _isRunning
                                ? Colors.redAccent
                                : const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _toggleServer,
                          icon: Icon(
                            _isRunning
                                ? Icons.stop_circle_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            _isRunning
                                ? 'Stop Wi-Fi Drop Server'
                                : 'Start Wi-Fi Drop Server',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // TABS
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabPill(
                          title: '📤 Send to PC',
                          isSelected: _activeTab == 0,
                          onTap: () => setState(() => _activeTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _TabPill(
                          title: '📥 Inbox ($totalInbox)',
                          isSelected: _activeTab == 1,
                          onTap: () => setState(() => _activeTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_activeTab == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.folder_open_rounded,
                                  color: Colors.teal,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Share File from Device',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _openGeminiStylePickerMenu,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 17,
                              ),
                              label: const Text(
                                'Choose File',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_selectedFileName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.teal,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$_selectedFileName (${_formatBytes(_selectedFileSize)})',
                                    style: const TextStyle(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.teal,
                                  ),
                                  onPressed: () => setState(() {
                                    _selectedFileName = null;
                                    _selectedFileBytes = null;
                                    _selectedFilePath = null;
                                    _selectedFileSize = 0;
                                  }),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            '"Choose File" par tap karke Gallery, Photos, PDF ya All Files chunein.',
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
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
                              'Live Text / Code Pad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textColor,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _shareTextAsFile,
                              icon: const Icon(
                                Icons.save_alt_rounded,
                                size: 15,
                              ),
                              label: const Text('Make .txt'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _textController,
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Yahan apna code, links, ya notes paste karein...',
                              hintStyle: TextStyle(color: subColor),
                              contentPadding: const EdgeInsets.all(14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (totalInbox == 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: subColor),
                          const SizedBox(height: 10),
                          Text(
                            'Inbox is Empty',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ..._receivedFiles.map(
                      (file) => Card(
                        color: cardColor,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: Icon(
                            file.isImage
                                ? Icons.image_rounded
                                : Icons.insert_drive_file_rounded,
                            color: Colors.teal,
                          ),
                          title: Text(
                            file.name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${file.sizeText} • ${file.timeText}',
                            style: TextStyle(color: subColor, fontSize: 12),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _saveReceivedFile(file),
                            child: const Text('Save'),
                          ),
                        ),
                      ),
                    ),
                    ..._receivedMessages.map(
                      (item) => Card(
                        color: cardColor,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          title: SelectableText(
                            item.text,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Received at ${item.timeText}',
                            style: TextStyle(color: subColor, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: Colors.indigoAccent,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied!')),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeminiOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _GeminiOptionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
