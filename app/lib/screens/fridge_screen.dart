import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fridge_item.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chip_selectors.dart';
import '../widgets/empty_state.dart';
import '../widgets/fridge_item_card.dart';
import '../widgets/loading_state.dart';
import '../widgets/product_nutrition_panel.dart';
import '../widgets/responsive_container.dart';
import '../widgets/section_card.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  final _barcodeCtrl = TextEditingController();
  int _days = 7;
  ProductInfo? _productPreview;
  bool _lookupLoading = false;
  bool _addLoading = false;
  String _filter = 'All';

  static const _units = ['pcs', 'g', 'kg', 'ml', 'L', 'cup', 'tbsp'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadFridge());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  List<FridgeItem> _filtered(List<FridgeItem> items) {
    switch (_filter) {
      case 'Expiring soon':
        return items.where((i) => i.daysToExpiry <= 5).toList();
      case 'Barcode items':
        return items.where((i) => i.barcode != null && i.barcode!.isNotEmpty).toList();
      case 'Safe ingredients':
        return items;
      default:
        return items;
    }
  }

  Future<void> _lookupBarcode() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _lookupLoading = true);
    final product = await context.read<AppState>().lookupBarcode(code);
    if (!mounted) return;
    setState(() => _lookupLoading = false);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found — you can still add manually')),
      );
      return;
    }
    setState(() {
      _productPreview = product;
      _nameCtrl.text = product.genericIngredient ?? product.productName ?? '';
    });
  }

  Future<void> _addItem() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _addLoading = true);
    await context.read<AppState>().addFridgeItem(
      name: name,
      quantity: _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      daysToExpiry: _days,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _addLoading = false);
      _nameCtrl.clear();
      _qtyCtrl.clear();
      _barcodeCtrl.clear();
      setState(() {
        _productPreview = null;
        _days = 7;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $name to fridge')),
      );
    }
  }

  Future<void> _confirmDelete(FridgeItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove ${item.ingredientName} from your fridge?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      await context.read<AppState>().deleteFridgeItem(item.itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${item.ingredientName}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = _filtered(state.fridge);
    final expiringSoon = state.fridge.where((i) => i.daysToExpiry <= 5).length;
    final barcodeCount = state.fridge.where((i) => i.barcode != null && i.barcode!.isNotEmpty).length;
    final wide = isWideLayout(context);

    return Padding(
      padding: AppTheme.pagePadding(context),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 16),
              _statsRow(state.fridge.length, expiringSoon, barcodeCount),
              const SizedBox(height: 16),
              FilterChipRow(
                options: const ['All', 'Expiring soon', 'Barcode items', 'Safe ingredients'],
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: wide ? _wideBody(context, state, items) : _narrowBody(context, state, items),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Fridge', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Track ingredients and expiry to power personalised recipes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _statsRow(int total, int expiringSoon, int barcodeCount) {
    return Row(
      children: [
        SummaryStatCard(label: 'Total items', value: '$total', icon: Icons.inventory_2_outlined, accent: AppTheme.primaryGreen),
        const SizedBox(width: 10),
        SummaryStatCard(label: 'Expiring soon', value: '$expiringSoon', icon: Icons.schedule, accent: AppTheme.warningOrange),
        const SizedBox(width: 10),
        SummaryStatCard(label: 'Barcode', value: '$barcodeCount', icon: Icons.qr_code_2, accent: AppTheme.primaryGreen),
      ],
    );
  }

  Widget _wideBody(BuildContext context, AppState state, List<FridgeItem> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _itemList(context, state, items),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: _addForm(),
          ),
        ),
      ],
    );
  }

  Widget _narrowBody(BuildContext context, AppState state, List<FridgeItem> items) {
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: state.loadFridge,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (state.loading && state.fridge.isEmpty)
            const LoadingState(message: 'Loading fridge…')
          else if (items.isEmpty)
            const EmptyState(
              icon: Icons.kitchen_outlined,
              title: 'Your fridge is empty',
              message: 'Add ingredients below to get personalised recipes.',
            )
          else
            ...items.map(
              (item) => FridgeItemCard(
                item: item,
                onDelete: () => _confirmDelete(item),
                onEdit: () => _editItem(context, item),
              ),
            ),
          const SizedBox(height: 16),
          _addForm(),
        ],
      ),
    );
  }

  Widget _itemList(BuildContext context, AppState state, List<FridgeItem> items) {
    if (state.loading && state.fridge.isEmpty) {
      return const LoadingState(message: 'Loading fridge…');
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.kitchen_outlined,
        title: 'Your fridge is empty',
        message: 'Add ingredients using the form on the right.',
      );
    }
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: state.loadFridge,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return FridgeItemCard(
            item: item,
            onDelete: () => _confirmDelete(item),
            onEdit: () => _editItem(context, item),
          );
        },
      ),
    );
  }

  Widget _addForm() {
    return SectionCard(
      title: 'Add ingredient',
      helper: 'Barcode demo: 6111246721261',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Ingredient name')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _units.contains(_unitCtrl.text) ? _unitCtrl.text : 'pcs',
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => _unitCtrl.text = v ?? 'pcs',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _barcodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Barcode (optional)',
              prefixIcon: Icon(Icons.qr_code_scanner),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event, size: 18, color: AppTheme.textMuted),
              const SizedBox(width: 8),
              Text('Days to expiry: $_days', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _days <= 2
                  ? AppTheme.dangerRed
                  : _days <= 5
                      ? AppTheme.warningOrange
                      : AppTheme.primaryGreen,
              thumbColor: AppTheme.primaryGreen,
              overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _days.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              label: '$_days days',
              onChanged: (v) => setState(() => _days = v.round()),
            ),
          ),
          if (_productPreview != null) ...[
            const SizedBox(height: 12),
            ProductNutritionPanel(
              product: _productPreview!,
              loading: _addLoading,
              onAdd: _addItem,
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addLoading ? null : _addItem,
                    icon: _addLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _lookupLoading ? null : _lookupBarcode,
                icon: _lookupLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('Lookup barcode'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editItem(BuildContext context, FridgeItem item) async {
    var days = item.daysToExpiry;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit ${item.ingredientName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Days to expiry: $days'),
              Slider(
                value: days.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => setDialogState(() => days = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      await context.read<AppState>().updateFridgeItem(item.itemId, {'days_to_expiry': days});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item updated')));
    }
  }
}
