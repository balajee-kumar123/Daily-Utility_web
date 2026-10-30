import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _lowerChars = 'abcdefghijklmnopqrstuvwxyz';
const _upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _numberChars = '0123456789';
const _defaultSymbols = '!@#\$%^&*()-_=+[]{};:,.<>?';
const _ambiguousChars = 'O0Il1|';

/// Password generate karne ka logic (UI se alag)
class PasswordGenerator {
  static final Random _rng = Random.secure();

  static List<String> _buildPools({
    required bool useUpper,
    required bool useNumbers,
    required bool useSymbols,
    required bool excludeAmbiguous,
    required String symbols,
  }) {
    final pools = <String>[_lowerChars];
    if (useUpper) pools.add(_upperChars);
    if (useNumbers) pools.add(_numberChars);
    if (useSymbols) {
      pools.add(symbols.isEmpty ? _defaultSymbols : symbols);
    }

    return pools
        .map((p) => excludeAmbiguous ? _removeChars(p, _ambiguousChars) : p)
        .where((p) => p.isNotEmpty)
        .toList();
  }

  static String _removeChars(String source, String toRemove) {
    return source.split('').where((c) => !toRemove.contains(c)).join();
  }

  /// Har selected set se kam se kam 1 character guarantee hota hai
  static String generate({
    required int length,
    required bool useUpper,
    required bool useNumbers,
    required bool useSymbols,
    required bool excludeAmbiguous,
    String symbols = '',
  }) {
    final pools = _buildPools(
      useUpper: useUpper,
      useNumbers: useNumbers,
      useSymbols: useSymbols,
      excludeAmbiguous: excludeAmbiguous,
      symbols: symbols,
    );
    final all = pools.join();

    final chars = <String>[
      for (final pool in pools) pool[_rng.nextInt(pool.length)],
    ];
    while (chars.length < length) {
      chars.add(all[_rng.nextInt(all.length)]);
    }
    chars.shuffle(_rng);
    return chars.take(length).join();
  }

  /// Entropy (bits) = length * log2(unique characters ki sankhya)
  static double entropyBits({
    required int length,
    required bool useUpper,
    required bool useNumbers,
    required bool useSymbols,
    required bool excludeAmbiguous,
    String symbols = '',
  }) {
    final pools = _buildPools(
      useUpper: useUpper,
      useNumbers: useNumbers,
      useSymbols: useSymbols,
      excludeAmbiguous: excludeAmbiguous,
      symbols: symbols,
    );
    final uniqueCount = pools.join().split('').toSet().length;
    return length * log(uniqueCount) / ln2;
  }
}

class StrengthInfo {
  final String label;
  final double value;
  final Color color;
  const StrengthInfo(this.label, this.value, this.color);
}

StrengthInfo strengthFor(double bits) {
  if (bits < 40) return const StrengthInfo('Weak', 0.25, Colors.red);
  if (bits < 60) return const StrengthInfo('Fair', 0.5, Colors.orange);
  if (bits < 80) return const StrengthInfo('Strong', 0.75, Colors.green);
  return const StrengthInfo('Very strong', 1, Colors.teal);
}

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  static const int _historyLimit = 20;
  static const Duration _clipboardClearDelay = Duration(seconds: 30);

  // Settings
  double _length = 16;
  bool _useUpper = true;
  bool _useNumbers = true;
  bool _useSymbols = true;
  bool _excludeAmbiguous = false;
  final TextEditingController _customSymbolsController = TextEditingController();

  // State
  String _password = '';
  bool _obscure = false;
  final List<String> _history = [];
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    _customSymbolsController.dispose();
    super.dispose();
  }

  /// Naya password banao (history mein add nahi karta)
  void _refresh() {
    final pwd = PasswordGenerator.generate(
      length: _length.toInt(),
      useUpper: _useUpper,
      useNumbers: _useNumbers,
      useSymbols: _useSymbols,
      excludeAmbiguous: _excludeAmbiguous,
      symbols: _customSymbolsController.text,
    );
    setState(() => _password = pwd);
  }

  /// Button dabane par: naya password + history mein save
  void _generateAndSave() {
    _refresh();
    setState(() {
      _history.insert(0, _password);
      if (_history.length > _historyLimit) {
        _history.removeRange(_historyLimit, _history.length);
      }
    });
  }

  /// Copy ke 30 second baad clipboard saaf, taki password lamba time clipboard mein na rahe
  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage("Password copy ho gaya");

    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(_clipboardClearDelay, () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bits = PasswordGenerator.entropyBits(
      length: _length.toInt(),
      useUpper: _useUpper,
      useNumbers: _useNumbers,
      useSymbols: _useSymbols,
      excludeAmbiguous: _excludeAmbiguous,
      symbols: _customSymbolsController.text,
    );
    final strength = strengthFor(bits);

    return Scaffold(
      appBar: AppBar(title: const Text("Password Generator")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Password display card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _obscure
                            ? Text(
                                "•" * _password.length,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20),
                              )
                            : SelectableText(
                                _password,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                      ),
                      IconButton(
                        tooltip: _obscure ? "Dikhao" : "Chhupao",
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: strength.value,
                      minHeight: 8,
                      color: strength.color,
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${strength.label} • ${bits.toStringAsFixed(0)} bits",
                    style: TextStyle(
                      color: strength.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(_password),
                      icon: const Icon(Icons.copy),
                      label: const Text("Copy"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Length
          Text("Length: ${_length.toInt()}", style: theme.textTheme.titleMedium),
          Slider(
            value: _length,
            min: 8,
            max: 64,
            divisions: 56,
            label: _length.toInt().toString(),
            onChanged: (v) {
              setState(() => _length = v);
              _refresh();
            },
          ),

          // Character options
          SwitchListTile(
            title: const Text("Uppercase (A-Z)"),
            value: _useUpper,
            onChanged: (v) {
              setState(() => _useUpper = v);
              _refresh();
            },
          ),
          SwitchListTile(
            title: const Text("Numbers (0-9)"),
            value: _useNumbers,
            onChanged: (v) {
              setState(() => _useNumbers = v);
              _refresh();
            },
          ),
          SwitchListTile(
            title: const Text("Symbols (!@#)"),
            value: _useSymbols,
            onChanged: (v) {
              setState(() => _useSymbols = v);
              _refresh();
            },
          ),
          SwitchListTile(
            title: const Text("Ambiguous characters hatao (O, 0, I, l, 1)"),
            value: _excludeAmbiguous,
            onChanged: (v) {
              setState(() => _excludeAmbiguous = v);
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customSymbolsController,
            decoration: const InputDecoration(
              labelText: "Custom symbols (khali = default)",
              hintText: "jaise !@#",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _refresh(),
          ),
          const SizedBox(height: 20),

          // Generate button
          FilledButton.icon(
            onPressed: _generateAndSave,
            icon: const Icon(Icons.refresh),
            label: const Text("Naya password banao"),
          ),

          // History
          if (_history.isNotEmpty) ...[
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text("History", style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => setState(() => _history.clear()),
                  child: const Text("Clear"),
                ),
              ],
            ),
            for (final pwd in _history)
              Card(
                child: ListTile(
                  title: Text(
                    pwd,
                    style: const TextStyle(fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copy(pwd),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}