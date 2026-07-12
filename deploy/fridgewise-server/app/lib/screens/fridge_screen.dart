import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  List<dynamic> _items = [];
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  int _days = 7;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    final data = await api.getInventory(ApiConfig.demoUserId);
    if (mounted) {
      setState(() {
        _items = data['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _addItem() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final api = context.read<ApiService>();
    await api.addInventoryItem(
      userId: ApiConfig.demoUserId,
      ingredientName: name,
      daysToExpiry: _days,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
    );
    _nameCtrl.clear();
    _barcodeCtrl.clear();
    await _load();
  }

  Future<void> _lookupBarcode() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    try {
      final api = context.read<ApiService>();
      final p = await api.lookupBarcode(code);
      _nameCtrl.text = p['generic_ingredient_name']?.toString() ?? p['product_name']?.toString() ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found: ${p['product_name'] ?? code}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Fridge')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Ingredient')),
                TextField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode (optional)')),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _days.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '$_days days',
                        onChanged: (v) => setState(() => _days = v.round()),
                      ),
                    ),
                    Text('$_days d'),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: FilledButton(onPressed: _addItem, child: const Text('Add'))),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _lookupBarcode, child: const Text('Lookup barcode')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final it = _items[i] as Map<String, dynamic>;
                      final days = it['days_to_expiry'] ?? 0;
                      final name = it['cleaned_ingredient_name'] ?? it['ingredient_name'] ?? '';
                      return ListTile(
                        title: Text('$name'),
                        subtitle: Text('Expires in $days days'),
                        trailing: days <= 3 ? const Icon(Icons.warning, color: Colors.red) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
