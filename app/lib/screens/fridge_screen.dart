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
import '../widgets/section_card.dart';
import '../utils/fridge_health.dart';

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
  String _storage = 'fridge';
  ProductInfo? _productPreview;
  bool _lookupLoading = false;
  bool _addLoading = false;
  String _filter = 'All';
  String _storageFilter = 'All storage';

  static const _units = ['pcs', 'g', 'kg', 'ml', 'L', 'cup', 'tbsp'];
  static const _storageOptions = [
    ('fridge', 'Fridge'),
    ('freezer', 'Freezer'),
    ('pantry', 'Pantry'),
  ];

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
    var list = items;
    switch (_filter) {
      case 'Expiring soon':
        list = list.where((i) => i.daysToExpiry <= 5).toList();
        break;
      case 'Barcode items':
        list = list.where((i) => i.barcode != null && i.barcode!.isNotEmpty).toList();
        break;
      case 'Depleting soon':
        list = list.where((i) => i.predictedDaysUntilDepletion <= 3).toList();
        break;
      default:
        break;
    }
    switch (_storageFilter) {
      case 'Fridge':
        return list.where((i) => i.storageLocation == 'fridge').toList();
      case 'Freezer':
        return list.where((i) => i.storageLocation == 'freezer').toList();
      case 'Pantry':
        return list.where((i) => i.storageLocation == 'pantry').toList();
      default:
        return list;
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _qtyCtrl.clear();
    _barcodeCtrl.clear();
    _unitCtrl.text = 'pcs';
    _days = 7;
    _storage = 'fridge';
    _productPreview = null;
  }

  Future<void> _lookupBarcode(StateSetter setModalState) async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    setModalState(() => _lookupLoading = true);
    final product = await context.read<AppState>().lookupBarcode(code);
    if (!mounted) return;
    setModalState(() {
      _lookupLoading = false;
      if (product != null) {
        _productPreview = product;
        _nameCtrl.text = product.genericIngredient ?? product.productName ?? '';
      }
    });
    if (product == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found — you can still add manually')),
      );
    }
  }

  Future<void> _addItem(StateSetter setModalState, {VoidCallback? onSuccess}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an ingredient name first')),
      );
      return;
    }
    setModalState(() => _addLoading = true);
    final ok = await context.read<AppState>().addFridgeItem(
      name: name,
      quantity: _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim(),
      unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
      daysToExpiry: _days,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      storageLocation: _storage,
    );
    if (!mounted) return;
    setModalState(() => _addLoading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add item — check API connection and try again')),
      );
      return;
    }
    final place = _storageOptions.firstWhere((e) => e.$1 == _storage).$2;
    setModalState(_resetForm);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $name to $place')),
    );
    onSuccess?.call();
  }

  Future<void> _openAddSheet() async {
    _resetForm();
    final wide = MediaQuery.sizeOf(context).width >= 700;

    if (wide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            child: _addForm(
                              setModalState: setModalState,
                              onAdded: () {
                                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
              ),
              child: SingleChildScrollView(
                child: _addForm(
                  setModalState: setModalState,
                  onAdded: () {
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                  },
                ),
              ),
            );
          },
        );
      },
    );
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: state.loadFridge,
      child: ListView(
        padding: AppTheme.pagePadding(context).copyWith(bottom: 120 + bottomInset),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: AppTheme.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  _fridgeHealthCard(FridgeHealthScore.from(state.fridge)),
                  const SizedBox(height: 16),
                  _statsRow(state.fridge.length, expiringSoon, barcodeCount),
                  const SizedBox(height: 16),
                  FilterChipRow(
                    options: const ['All', 'Expiring soon', 'Depleting soon', 'Barcode items'],
                    selected: _filter,
                    onSelected: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 8),
                  FilterChipRow(
                    options: const ['All storage', 'Fridge', 'Freezer', 'Pantry'],
                    selected: _storageFilter,
                    onSelected: (v) => setState(() => _storageFilter = v),
                  ),
                  const SizedBox(height: 16),
                  if (state.loading && state.fridge.isEmpty)
                    const LoadingState(message: 'Loading fridge…')
                  else if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.kitchen_outlined,
                      title: 'Your fridge is empty',
                      message: 'Tap Add item to put food in fridge, freezer, or pantry.',
                    )
                  else
                    ...items.map(
                      (item) => FridgeItemCard(
                        item: item,
                        onDelete: () => _confirmDelete(item),
                        onEdit: () => _editItem(context, item),
                        onStorageChanged: (loc) => context.read<AppState>().setStorageLocation(item.itemId, loc),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final title = Column(
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
        final button = FilledButton.icon(
          onPressed: _openAddSheet,
          icon: const Icon(Icons.add),
          label: Text(compact ? 'Add' : 'Add item'),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: button),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }

  Widget _fridgeHealthCard(FridgeHealthScore health) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: health.score / 100,
                    strokeWidth: 7,
                    backgroundColor: AppTheme.iceLight,
                    color: health.color,
                  ),
                ),
                Text(
                  '${health.score}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: health.color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fridge health · ${health.label}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(health.summary, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  '${health.freshCount} fresh · ${health.soonCount} soon · ${health.criticalCount} urgent',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(int total, int expiringSoon, int barcodeCount) {
    final cards = [
      SummaryStatCard(label: 'Total items', value: '$total', icon: Icons.inventory_2_outlined, accent: AppTheme.primaryGreen, expand: false),
      SummaryStatCard(label: 'Expiring soon', value: '$expiringSoon', icon: Icons.schedule, accent: AppTheme.warningOrange, expand: false),
      SummaryStatCard(label: 'Barcode', value: '$barcodeCount', icon: Icons.qr_code_2, accent: AppTheme.primaryGreen, expand: false),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  SizedBox(width: 148, child: cards[i]),
                ],
              ],
            ),
          );
        }
        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
            const SizedBox(width: 10),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }

  Widget _addForm({
    required StateSetter setModalState,
    VoidCallback? onAdded,
  }) {
    final unit = _units.contains(_unitCtrl.text) ? _unitCtrl.text : 'pcs';
    return SectionCard(
      title: 'Add ingredient',
      helper: 'Barcode demo: 6111246721261',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Ingredient name'),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 340;
              final qty = TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
              );
              final unitField = DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setModalState(() => _unitCtrl.text = v ?? 'pcs'),
              );
              if (stacked) {
                return Column(
                  children: [
                    qty,
                    const SizedBox(height: 10),
                    unitField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: qty),
                  const SizedBox(width: 10),
                  Expanded(child: unitField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text('Storage location', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in _storageOptions)
                ChoiceChip(
                  label: Text(opt.$2),
                  selected: _storage == opt.$1,
                  onSelected: (_) => setModalState(() => _storage = opt.$1),
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
              onChanged: (v) => setModalState(() => _days = v.round()),
            ),
          ),
          if (_productPreview != null) ...[
            const SizedBox(height: 12),
            ProductNutritionPanel(
              product: _productPreview!,
              loading: _addLoading,
              onAdd: () => _addItem(setModalState, onSuccess: onAdded),
            ),
          ] else ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addLoading ? null : () => _addItem(setModalState, onSuccess: onAdded),
              icon: _addLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add item'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _lookupLoading ? null : () => _lookupBarcode(setModalState),
              icon: _lookupLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('Lookup barcode'),
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
