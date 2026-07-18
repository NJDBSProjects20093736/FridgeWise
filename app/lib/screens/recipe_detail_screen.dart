import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_recommendation.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/badges.dart';
import '../widgets/food_image.dart';
import '../utils/food_imagery.dart';
import '../widgets/loading_state.dart';
import '../widgets/responsive_container.dart';
import '../widgets/section_card.dart';
import '../services/local_store.dart';
import 'cooking_mode_screen.dart';
import 'shopping_list_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  final RecipeRecommendation summary;

  const RecipeDetailScreen({super.key, required this.recipeId, required this.summary});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _localStore = LocalStore();
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _explanation;
  bool _loading = true;
  RecipeProgress _progress = RecipeProgress.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    final progress = await _localStore.loadRecipeProgress(widget.recipeId);
    try {
      final d = await repo.getRecipe(widget.recipeId);
      final e = await repo.getExplanation(widget.recipeId, AppState.demoUserId);
      if (mounted) {
        setState(() {
          _detail = d;
          _explanation = e;
          _progress = progress;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _progress = progress; _loading = false; });
    }
  }

  Future<void> _toggleIngredient(int index) async {
    final next = Set<int>.from(_progress.ingredients);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    final updated = _progress.copyWith(ingredients: next);
    setState(() => _progress = updated);
    await _localStore.saveRecipeProgress(widget.recipeId, updated);
  }

  Future<void> _toggleMissing(int index) async {
    final next = Set<int>.from(_progress.missing);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    final updated = _progress.copyWith(missing: next);
    setState(() => _progress = updated);
    await _localStore.saveRecipeProgress(widget.recipeId, updated);
  }

  Future<void> _toggleStep(int index) async {
    final next = Set<int>.from(_progress.steps);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    final updated = _progress.copyWith(steps: next);
    setState(() => _progress = updated);
    await _localStore.saveRecipeProgress(widget.recipeId, updated);
  }

  String _progressLabel(int done, int total) {
    if (total == 0) return 'Tick items as you gather and cook';
    return '$done of $total ticked — tap to mark as you go';
  }

  List<String> _list(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : [];

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final ingredients = _detail != null ? _list(_detail!['ingredients']) : <String>[];
    final steps = _detail != null ? _list(_detail!['steps']) : <String>[];
    final why = _explanation?['why_recommended'] != null ? _list(_explanation!['why_recommended']) : s.whyRecommended;
    final safety = _explanation?['safety_notes'] != null ? _list(_explanation!['safety_notes']) : <String>[];
    final nutritionNotes = _explanation?['nutrition_notes'] != null ? _list(_explanation!['nutrition_notes']) : <String>[];
    final subs = _explanation?['substitutions'] is List ? (_explanation!['substitutions'] as List).cast<Map>() : [];
    final wide = MediaQuery.sizeOf(context).width > 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Shopping list',
            icon: const Icon(Icons.shopping_basket_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: (!_loading && steps.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CookingModeScreen(
                    recipeId: widget.recipeId,
                    recipeName: s.name,
                    steps: steps,
                  ),
                ),
              ),
              icon: const Icon(Icons.restaurant),
              label: const Text('Cooking mode'),
            )
          : null,
      body: _loading
          ? const LoadingState(message: 'Loading recipe…')
          : ResponsiveContainer(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _leftColumn(s, ingredients, safety, nutritionNotes, subs)),
                        const SizedBox(width: 24),
                        Expanded(child: _rightColumn(why, steps, s)),
                      ],
                    )
                  : ListView(
                      children: [
                        _summaryCard(s),
                        const SizedBox(height: 16),
                        _impactCard(s, ingredients),
                        const SizedBox(height: 14),
                        _ratingCard(s),
                        const SizedBox(height: 14),
                        _whyCard(why),
                        const SizedBox(height: 14),
                        _agentsCard(s),
                        const SizedBox(height: 14),
                        _ingredientsCard(ingredients, s),
                        const SizedBox(height: 14),
                        _stepsCard(steps),
                        if (safety.isNotEmpty) ...[const SizedBox(height: 14), _safetyCard(safety)],
                        if (nutritionNotes.isNotEmpty) ...[const SizedBox(height: 14), _nutritionCard(nutritionNotes)],
                        if (subs.isNotEmpty) ...[const SizedBox(height: 14), _subsCard(subs)],
                        const SizedBox(height: 88),
                      ],
                    ),
            ),
    );
  }

  bool _isMissing(String ingredient, List<String> missing) {
    final ing = ingredient.toLowerCase();
    for (final m in missing) {
      final miss = m.toLowerCase();
      if (ing == miss || ing.contains(miss) || miss.contains(ing)) return true;
    }
    return false;
  }

  Widget _impactCard(RecipeRecommendation s, List<String> ingredients) {
    final total = ingredients.isEmpty ? (s.missingCount + s.expiringUsed.length).clamp(1, 99) : ingredients.length;
    final haveCount = (total - s.missingCount).clamp(0, total);
    final utilisation = total == 0 ? 0.0 : haveCount / total;
    final wasteKg = (s.expiringUsed.length * 0.12 + haveCount * 0.04).clamp(0.05, 2.5);
    final savedEuros = (s.expiringUsed.length * 3.5 + haveCount * 1.2).round().clamp(1, 40);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: AppTheme.iceLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Impact if you cook this', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _impactTile('${(utilisation * 100).round()}%', 'Fridge utilised')),
              Expanded(child: _impactTile('~${wasteKg.toStringAsFixed(1)} kg', 'Waste avoided')),
              Expanded(child: _impactTile('€$savedEuros', 'Money saved')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _impactTile(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _leftColumn(RecipeRecommendation s, List<String> ingredients, List<String> safety, List<String> nutritionNotes, List<dynamic> subs) {
    return ListView(
      children: [
        _summaryCard(s),
        const SizedBox(height: 16),
        _impactCard(s, ingredients),
        const SizedBox(height: 14),
        _ratingCard(s),
        const SizedBox(height: 14),
        _ingredientsCard(ingredients, s),
        if (safety.isNotEmpty) ...[const SizedBox(height: 14), _safetyCard(safety)],
        if (nutritionNotes.isNotEmpty) ...[const SizedBox(height: 14), _nutritionCard(nutritionNotes)],
        if (subs.isNotEmpty) ...[const SizedBox(height: 14), _subsCard(subs)],
        const SizedBox(height: 88),
      ],
    );
  }

  Widget _rightColumn(List<String> why, List<String> steps, RecipeRecommendation s) {
    return ListView(
      children: [
        _whyCard(why),
        const SizedBox(height: 14),
        _agentsCard(s),
        const SizedBox(height: 14),
        _stepsCard(steps),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget _ratingCard(RecipeRecommendation s) {
    final state = context.watch<AppState>();
    final rating = state.recipeRatings[s.recipeId] ?? 0;
    return SectionCard(
      title: 'Rate this recipe',
      helper: 'Your ratings improve future preference learning.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () => state.rateRecipe(s.recipeId, star),
                icon: Icon(
                  star <= rating ? Icons.star : Icons.star_border,
                  color: AppTheme.warningOrange,
                ),
              );
            }),
          ),
          TextButton.icon(
            onPressed: () async {
              await state.markRecipeCooked(s.recipeId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged as cooked — sustainability stats updated')),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('I cooked this'),
          ),
        ],
      ),
    );
  }

  Widget _agentsCard(RecipeRecommendation s) {
    final parts = context.read<AppState>().scoreBreakdown(s);
    final maxAbs = parts.fold<double>(0.01, (m, e) => e.value.abs() > m ? e.value.abs() : m);
    return SectionCard(
      title: 'Multi-agent score breakdown',
      helper: 'Expiry, match, nutrition, preference agents + missing penalty',
      child: Column(
        children: parts.map((e) {
          final pct = (e.value.abs() / maxAbs).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(e.value >= 0 ? '+${e.value.toStringAsFixed(2)}' : e.value.toStringAsFixed(2)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppTheme.iceLight,
                    color: e.value >= 0 ? AppTheme.primaryGreen : AppTheme.dangerRed,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryCard(RecipeRecommendation s) {
    final hints = FoodImagery.ingredientHints(s.name, s.expiringUsed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              FoodImage(label: s.name, height: 220, borderRadius: BorderRadius.circular(16)),
              Positioned(
                bottom: 12,
                right: 12,
                child: ScoreBadge(matchPct: s.matchPct, size: 72, glowing: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: AppTheme.cardDecoration(color: AppTheme.frost),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              IngredientAvatarRow(ingredients: hints, size: 36),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text('${s.prepTimeMinutes} min prep', style: Theme.of(context).textTheme.bodySmall),
                  if (s.difficultyLevel.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(s.difficultyLevel, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const Spacer(),
                  SafetyBadge(safe: s.safetyPassed),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (s.expiringUsed.isNotEmpty) ExpiryChip(count: s.expiringUsed.length, items: s.expiringUsed),
                  TagChip(label: 'Nutrition ${s.nutritionScore.toStringAsFixed(1)}', icon: Icons.eco_outlined),
                  if (s.missingCount > 0) TagChip(label: '${s.missingCount} missing', icon: Icons.shopping_basket_outlined, color: AppTheme.warningOrange),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _whyCard(List<String> why) {
    return Container(
      decoration: AppTheme.heroDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.glacier, size: 20),
              const SizedBox(width: 8),
              Text(
                'Why recommended',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...why.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppTheme.glacier),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        w,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textDark,
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _ingredientsCard(List<String> ingredients, RecipeRecommendation s) {
    final source = ingredients.isNotEmpty ? ingredients : [...s.expiringUsed, ...s.missing];
    final alreadyHave = <MapEntry<int, String>>[];
    final needToBuy = <MapEntry<int, String>>[];
    for (final entry in source.asMap().entries) {
      if (_isMissing(entry.value, s.missing)) {
        needToBuy.add(entry);
      } else {
        alreadyHave.add(entry);
      }
    }
    // Keep recipe missing list if source had no overlap parse
    if (needToBuy.isEmpty && s.missing.isNotEmpty) {
      for (var i = 0; i < s.missing.length; i++) {
        needToBuy.add(MapEntry(1000 + i, s.missing[i]));
      }
    }

    final utilisation = source.isEmpty ? 0.0 : alreadyHave.length / source.length;

    return SectionCard(
      title: 'Ingredients',
      helper: '${(utilisation * 100).round()}% already in your fridge — tick as you gather',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: utilisation.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.iceLight,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text('Already have (${alreadyHave.length})', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (alreadyHave.isEmpty)
            Text('None matched yet — add fridge items to improve this.', style: Theme.of(context).textTheme.bodySmall)
          else
            ...alreadyHave.map((entry) {
              final checked = _progress.ingredients.contains(entry.key);
              return _checkableRow(
                label: entry.value,
                checked: checked,
                onChanged: () => _toggleIngredient(entry.key),
              );
            }),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Need to buy (${needToBuy.length})', style: Theme.of(context).textTheme.labelLarge),
              ),
              if (needToBuy.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final added = await context.read<AppState>().addMissingToShoppingList(
                          needToBuy.map((e) => e.value).toList(),
                          recipeName: s.name,
                        );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(added == 0 ? 'Already on your shopping list' : 'Added $added item(s) to shopping list'),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Add to list'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (needToBuy.isEmpty)
            Text('You have everything for this recipe.', style: Theme.of(context).textTheme.bodySmall)
          else
            ...needToBuy.asMap().entries.map((indexed) {
              final entry = indexed.value;
              final missingIndex = indexed.key;
              final checked = _progress.missing.contains(missingIndex);
              return _checkableRow(
                label: entry.value,
                checked: checked,
                onChanged: () => _toggleMissing(missingIndex),
                accent: AppTheme.warningOrange,
              );
            }),
        ],
      ),
    );
  }

  Widget _checkableRow({
    required String label,
    required bool checked,
    required VoidCallback onChanged,
    Color? accent,
  }) {
    final color = accent ?? AppTheme.primaryGreen;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          decoration: checked ? TextDecoration.lineThrough : null,
          color: checked ? AppTheme.textMuted : AppTheme.textDark,
        );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => onChanged(),
                  activeColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: textStyle)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepsCard(List<String> steps) {
    final done = _progress.steps.length;
    return SectionCard(
      title: 'Method / steps',
      helper: steps.isEmpty ? null : _progressLabel(done, steps.length),
      child: steps.isEmpty
          ? Text(_detail?['description']?.toString() ?? 'No steps available.', style: Theme.of(context).textTheme.bodyMedium)
          : Column(
              children: [
                if (done > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: done / steps.length,
                        minHeight: 6,
                        backgroundColor: AppTheme.iceLight,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ...List.generate(steps.length, (i) {
                  final checked = _progress.steps.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleStep(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: AppTheme.cardDecoration(
                            color: checked ? AppTheme.iceLight : AppTheme.background,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: Checkbox(
                                  value: checked,
                                  onChanged: (_) => _toggleStep(i),
                                  activeColor: AppTheme.primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 10),
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: checked ? AppTheme.primaryGreen.withValues(alpha: 0.25) : AppTheme.primaryGreen,
                                child: checked
                                    ? Icon(Icons.check, size: 16, color: AppTheme.primaryGreen)
                                    : Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  steps[i],
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        decoration: checked ? TextDecoration.lineThrough : null,
                                        color: checked ? AppTheme.textMuted : AppTheme.textDark,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _safetyCard(List<String> safety) {
    return SectionCard(
      title: 'Allergy & dietary safety',
      child: Column(
        children: safety.map((n) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 10),
                Expanded(child: Text(n)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _nutritionCard(List<String> notes) {
    return SectionCard(
      title: 'Nutrition notes',
      child: Column(
        children: notes.map((n) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.eco_outlined, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 10),
                Expanded(child: Text(n)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _subsCard(List<dynamic> subs) {
    return SectionCard(
      title: 'Possible substitutions',
      child: Column(
        children: subs.map((sub) {
          return Card(
            color: AppTheme.background,
            child: ListTile(
              title: Text('${sub['missing']} → ${sub['substitute']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(sub['reason']?.toString() ?? ''),
            ),
          );
        }).toList(),
      ),
    );
  }
}
