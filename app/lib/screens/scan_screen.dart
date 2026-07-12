import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rescue_result.dart';
import '../models/scanned_product.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/product_safety.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/product_nutrition_panel.dart';
import '../widgets/recipe_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/section_card.dart';
import 'recipe_detail_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _barcodeCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  ScanMode _mode = ScanMode.rescueBasket;
  bool _lookupLoading = false;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _lookupLoading = true);
    final state = context.read<AppState>();
    final scanned = await state.lookupAndScan(code, _mode);
    if (!mounted) return;
    setState(() => _lookupLoading = false);
    if (scanned == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found — check barcode or add manually in Fridge')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scanned = state.lastScanned;
    final rescue = state.lastRescueResult;
    final safety = scanned != null
        ? ProductSafetyCheck.evaluate(
            profile: state.profile,
            productName: scanned.productName,
            genericIngredient: scanned.genericIngredient,
            allergens: scanned.allergens,
          )
        : null;

    return ResponsiveContainer(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Text('Scan food', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Check recipes before you buy discounted or near-expiry food.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.frostPanelDecoration(),
            child: const Row(
              children: [
                Icon(Icons.shopping_basket_outlined, color: AppTheme.glacier, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rescue Basket — scan discounted food and get recipe ideas before buying.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _modeCards(),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Barcode',
            helper: 'Demo: 6111246721261',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _barcodeCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Enter or scan barcode',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _lookupLoading ? null : _lookup,
                  icon: _lookupLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search),
                  label: const Text('Lookup product'),
                ),
              ],
            ),
          ),
          if (scanned != null) ...[
            const SizedBox(height: 16),
            if (safety != null && !safety.safe) _safetyBanner(safety.warnings),
            ProductNutritionPanel(
              product: scanned.toProductInfo(),
              onAdd: _mode == ScanMode.fridgeScan ? () => _addToFridge(state) : null,
            ),
            const SizedBox(height: 14),
            _expirySection(scanned, state),
            const SizedBox(height: 14),
            if (_mode == ScanMode.rescueBasket) ...[
              _rescueActions(state, rescue),
              if (state.rescueLoading) const LoadingState(message: 'Finding recipe ideas…'),
              if (rescue != null) _rescueVerdictCard(rescue),
              if (rescue != null && rescue.recipes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Recipe previews', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...rescue.topRecipes.map(
                  (r) => RecipeCard(
                    recipe: r,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.recipeId, summary: r)),
                    ),
                  ),
                ),
              ],
            ] else
              _fridgeActions(state),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.qr_code_scanner,
                title: 'Scan a product',
                message: 'Choose a mode above, enter a barcode, and lookup the product.',
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeCards() {
    return Row(
      children: [
        Expanded(child: _modeCard(ScanMode.fridgeScan, 'Add to my fridge', Icons.kitchen, 'Item already at home')),
        const SizedBox(width: 12),
        Expanded(child: _modeCard(ScanMode.rescueBasket, 'Scan before buying', Icons.shopping_cart_outlined, 'Supermarket rescue')),
      ],
    );
  }

  Widget _modeCard(ScanMode mode, String title, IconData icon, String subtitle) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () {
        setState(() => _mode = mode);
        context.read<AppState>().clearScanSession();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lightGreen : AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppTheme.primaryGreen : AppTheme.cardBorder, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppTheme.primaryGreen : AppTheme.textMuted),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppTheme.primaryGreen : AppTheme.textDark)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _safetyBanner(List<String> warnings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: warnings.map((w) => Text(w, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expirySection(ScannedProduct scanned, AppState state) {
    final chips = [
      (0, 'Expires today'),
      (1, 'Tomorrow'),
      (3, '3 days'),
      (7, '1 week'),
    ];
    return SectionCard(
      title: 'Expected expiry',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((c) {
              final selected = scanned.daysToExpiry == c.$1 || (c.$1 == 7 && scanned.daysToExpiry >= 7);
              return ChoiceChip(
                label: Text(c.$2),
                selected: selected,
                onSelected: (_) => state.updateScannedExpiry(c.$1 == 0 ? 1 : c.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Slider(
            value: scanned.daysToExpiry.clamp(1, 30).toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '${scanned.daysToExpiry} days',
            activeColor: scanned.daysToExpiry <= 2
                ? AppTheme.dangerRed
                : scanned.daysToExpiry <= 5
                    ? AppTheme.warningOrange
                    : AppTheme.primaryGreen,
            onChanged: (v) => state.updateScannedExpiry(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _fridgeActions(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity (optional)')),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _addToFridge(state),
          icon: const Icon(Icons.add),
          label: const Text('Add to fridge'),
        ),
      ],
    );
  }

  Widget _rescueActions(AppState state, RescueResult? rescue) {
    final safe = rescue?.productSafe ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: state.rescueLoading ? null : () => state.fetchRescueRecommendations(),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Get recipe ideas'),
        ),
        const SizedBox(height: 8),
        if (safe) ...[
          OutlinedButton.icon(
            onPressed: () => _addToFridge(state),
            icon: const Icon(Icons.kitchen),
            label: const Text('Add to fridge'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await state.addScannedToRescueBasket();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to rescue basket')));
              }
            },
            icon: const Icon(Icons.shopping_basket_outlined),
            label: const Text('Add to rescue basket'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            state.clearScanSession();
            _barcodeCtrl.clear();
          },
          child: const Text('Not buying'),
        ),
      ],
    );
  }

  Widget _rescueVerdictCard(RescueResult rescue) {
    Color color;
    IconData icon;
    switch (rescue.verdict) {
      case 'good_buy':
        color = AppTheme.goodTeal;
        icon = Icons.thumb_up_outlined;
        break;
      case 'not_recommended':
        color = AppTheme.dangerRed;
        icon = Icons.block;
        break;
      default:
        color = AppTheme.warningOrange;
        icon = Icons.info_outline;
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(color: color.withValues(alpha: 0.08)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(rescue.verdictLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(rescue.verdictReason, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            'Uses ${rescue.fridgeItemsUsed} fridge items · ${rescue.recipes.length} recipes found',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _addToFridge(AppState state) async {
    await state.addScannedToFridge(quantity: _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to fridge — recommendations updated')));
      state.clearScanSession();
      _barcodeCtrl.clear();
      _qtyCtrl.clear();
    }
  }
}
