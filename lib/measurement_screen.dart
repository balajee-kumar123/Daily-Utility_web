import 'package:flutter/material.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  final TextEditingController _inputController = TextEditingController();

  String _category = 'Length';
  String _fromUnit = 'Meter';
  String _toUnit = 'Feet';
  double _result = 0.0;

  final Map<String, List<String>> _units = {
    'Length': [
      'Meter',
      'Centimeter',
      'Millimeter',
      'Kilometer',
      'Inch',
      'Feet',
      'Yard',
      'Mile',
    ],
    'Weight': ['Kilogram', 'Gram', 'Milligram', 'Ton', 'Pound', 'Ounce'],
    'Temperature': ['Celsius', 'Fahrenheit', 'Kelvin'],
    'Area': ['Sq Meter', 'Sq Feet', 'Sq Yard (Gaj)', 'Acre', 'Hectare'],
    'Volume': ['Liter', 'Milliliter', 'Gallon', 'Cup'],
    'Speed': ['Km/h', 'Meter/sec', 'Miles/h (mph)'],
  };

  // Base unit ke hisaab se conversion factors
  final Map<String, double> _factors = {
    // Length (Base: Meter)
    'Meter': 1.0,
    'Centimeter': 0.01,
    'Millimeter': 0.001,
    'Kilometer': 1000.0,
    'Inch': 0.0254,
    'Feet': 0.3048,
    'Yard': 0.9144,
    'Mile': 1609.344,

    // Weight (Base: Kilogram)
    'Kilogram': 1.0,
    'Gram': 0.001,
    'Milligram': 0.000001,
    'Ton': 1000.0,
    'Pound': 0.45359237,
    'Ounce': 0.02834952,

    // Area (Base: Sq Meter)
    'Sq Meter': 1.0,
    'Sq Feet': 0.092903,
    'Sq Yard (Gaj)': 0.836127,
    'Acre': 4046.856,
    'Hectare': 10000.0,

    // Volume (Base: Liter)
    'Liter': 1.0,
    'Milliliter': 0.001,
    'Gallon': 3.78541,
    'Cup': 0.24,

    // Speed (Base: Meter/sec)
    'Meter/sec': 1.0,
    'Km/h': 0.277778,
    'Miles/h (mph)': 0.44704,
  };

  void _convert() {
    double? val = double.tryParse(_inputController.text.trim());
    if (val == null) {
      setState(() => _result = 0.0);
      return;
    }

    double res = 0.0;
    if (_category == 'Temperature') {
      res = _convertTemp(val, _fromUnit, _toUnit);
    } else {
      double inBase = val * (_factors[_fromUnit] ?? 1.0);
      res = inBase / (_factors[_toUnit] ?? 1.0);
    }

    setState(() {
      _result = res;
    });
  }

  double _convertTemp(double val, String from, String to) {
    if (from == to) return val;
    double celsius = val;
    if (from == 'Fahrenheit') celsius = (val - 32) * 5 / 9;
    if (from == 'Kelvin') celsius = val - 273.15;

    if (to == 'Fahrenheit') return (celsius * 9 / 5) + 32;
    if (to == 'Kelvin') return celsius + 273.15;
    return celsius;
  }

  void _swapUnits() {
    setState(() {
      String temp = _fromUnit;
      _fromUnit = _toUnit;
      _toUnit = temp;
      _convert();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> currentUnits = _units[_category]!;

    return Scaffold(
      backgroundColor: Colors.purple.shade50,
      appBar: AppBar(
        title: const Text('All-in-One Measurement'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Category Chips
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: _units.keys.map((cat) {
                final bool isSelected = _category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: Colors.purple,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _category = cat;
                      _fromUnit = _units[_category]![0];
                      _toUnit = _units[_category]![1];
                      _convert();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 2. Value Input
            TextField(
              controller: _inputController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Enter Value to Convert',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.calculate, color: Colors.purple),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _inputController.clear();
                    _convert();
                  },
                ),
              ),
              onChanged: (_) => _convert(),
            ),
            const SizedBox(height: 20),

            // 3. From & To Dropdowns with Swap Button
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _fromUnit,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'From',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: currentUnits
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _fromUnit = val!;
                        _convert();
                      });
                    },
                  ),
                ),
                IconButton(
                  onPressed: _swapUnits,
                  icon: const Icon(
                    Icons.swap_horiz,
                    color: Colors.purple,
                    size: 32,
                  ),
                  tooltip: 'Swap Units',
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _toUnit,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'To',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: currentUnits
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _toUnit = val!;
                        _convert();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 4. Result Display Card
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
                border: Border.all(color: Colors.purple.shade200, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '${_inputController.text.isEmpty ? "0" : _inputController.text} $_fromUnit =',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    '${_result.toStringAsFixed(4).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "")} $_toUnit',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
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
