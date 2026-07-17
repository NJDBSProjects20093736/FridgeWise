import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/rescue_result.dart';
import '../models/scanned_product.dart';
import '../providers/app_state.dart';
import '../services/thrifty_chef_repository.dart';
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
  bool _cameraOpening = false;

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
    try {
      final state = context.read<AppState>();
      final scanned = await state.lookupAndScan(code, _mode);
      if (!mounted) return;
      if (scanned == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found — check barcode or add manually in Fridge')),
        );
      }
    } on ProductLookupException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product lookup failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _lookupLoading = false);
      }
    }
  }

  Future<void> _scanWithCamera() async {
    if (_cameraOpening) return;
    setState(() => _cameraOpening = true);
    try {
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.black,
        builder: (context) => const _BarcodeScannerSheet(),
      );
      if (!mounted || code == null || code.trim().isEmpty) return;
      _barcodeCtrl.text = code.trim();
      await _lookup();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera scanner on this device/browser.')),
      );
    } finally {
      if (mounted) {
        setState(() => _cameraOpening = false);
      }
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
            child: Row(
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
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _lookupLoading ? null : _lookup,
                        icon: _lookupLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: const Text('Lookup product'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cameraOpening ? null : _scanWithCamera,
                        icon: _cameraOpening
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.photo_camera_outlined),
                        label: const Text('Scan camera'),
                      ),
                    ),
                  ],
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
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  const EmptyState(
                    icon: Icons.qr_code_scanner,
                    title: 'Scan a product',
                    message: 'Choose a mode above, scan with the camera or enter a barcode, then lookup the product.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 240,
                    child: FilledButton.icon(
                      onPressed: _cameraOpening ? null : _scanWithCamera,
                      icon: _cameraOpening
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.photo_camera_outlined),
                      label: const Text('Open camera scanner'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Or type the barcode above if camera access is unavailable.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final fridge = _modeCard(ScanMode.fridgeScan, 'Add to my fridge', Icons.kitchen_outlined, 'Item already at home');
        final rescue = _modeCard(ScanMode.rescueBasket, 'Scan before buying', Icons.shopping_bag_outlined, 'Supermarket rescue');
        if (stacked) {
          return Column(
            children: [
              fridge,
              const SizedBox(height: 12),
              rescue,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: fridge),
            const SizedBox(width: 12),
            Expanded(child: rescue),
          ],
        );
      },
    );
  }

  Widget _modeCard(ScanMode mode, String title, IconData icon, String subtitle) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () {
        setState(() => _mode = mode);
        context.read<AppState>().clearScanSession();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppTheme.iceLight : AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : AppTheme.cardBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : AppTheme.softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : AppTheme.iceLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: selected ? AppTheme.primaryGreen : AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: selected ? AppTheme.glacierDeep : AppTheme.textDark,
              ),
            ),
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
          Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: warnings.map((w) => Text(w, style: TextStyle(fontSize: 13, color: AppTheme.dangerRed))).toList(),
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
          const SizedBox(height: 12),
          Text(
            'Uses ${rescue.fridgeItemsUsed} fridge items · ${rescue.recipes.length} recipes found',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _rescueImpactRow(rescue),
        ],
      ),
    );
  }

  Widget _rescueImpactRow(RescueResult rescue) {
    final recipes = rescue.recipes.length;
    final worthBuying = rescue.verdict == 'good_buy'
        ? 'Yes'
        : rescue.verdict == 'not_recommended'
            ? 'No'
            : 'Maybe';
    final moneySaved = (recipes * 2.5 + rescue.fridgeItemsUsed * 1.5).round().clamp(1, 45);
    final wasteKg = (0.15 + recipes * 0.08).clamp(0.1, 2.0);

    Widget tile(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: AppTheme.cardDecoration(color: AppTheme.background),
            child: Column(
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );

    return Row(
      children: [
        tile(worthBuying, 'Worth buying?'),
        const SizedBox(width: 8),
        tile('$recipes', 'Recipes unlocked'),
        const SizedBox(width: 8),
        tile('€$moneySaved', 'Est. saved'),
        const SizedBox(width: 8),
        tile('~${wasteKg.toStringAsFixed(1)}kg', 'Waste avoided'),
      ],
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

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
    ],
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleCapture,
              errorBuilder: (context, error) {
                return Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'Camera scanner unavailable',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Align the barcode inside the frame',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _controller.toggleTorch,
                  icon: const Icon(Icons.flashlight_on_outlined),
                ),
              ],
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
