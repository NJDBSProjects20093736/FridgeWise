import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/responsive_container.dart';
import '../widgets/section_card.dart';

class IngredientSimilarityScreen extends StatefulWidget {
  const IngredientSimilarityScreen({super.key});

  @override
  State<IngredientSimilarityScreen> createState() => _IngredientSimilarityScreenState();
}

class _IngredientSimilarityScreenState extends State<IngredientSimilarityScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  // Debounced type-ahead against the backend vocabulary.
  late final _Debounceable<List<String>?, String> _debouncedLookup;
  List<String> _lastOptions = const [];

  static const suggestions = ['miso', 'tempeh', 'kimchi', 'cassava', 'jackfruit', 'pandan', 'plantain'];

  @override
  void initState() {
    super.initState();
    _debouncedLookup = _debounce(_lookup);
  }

  Future<List<String>?> _lookup(String query) {
    return context.read<AppState>().repo.searchIngredientNames(query);
  }

  Future<Iterable<String>> _optionsBuilder(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Iterable<String>.empty();
    final result = await _debouncedLookup(trimmed);
    // A null result means this call was superseded by a newer keystroke;
    // keep showing the previous options instead of flickering to empty.
    if (result == null) return _lastOptions;
    _lastOptions = result;
    return result;
  }

  Future<void> _search([String? preset]) async {
    final q = (preset ?? _ctrl.text).trim();
    if (q.isEmpty) return;
    _ctrl.text = q;
    _focus.unfocus();
    setState(() => _loading = true);
    final hits = await context.read<AppState>().repo.similarIngredients(q, AppState.demoUserId);
    if (mounted) setState(() { _results = hits; _loading = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Text('Ingredient substitutes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Find familiar alternatives for new or uncommon ingredients.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.frostPanelDecoration(),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppTheme.glacier, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This helps the recommender handle unfamiliar ingredients.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Search ingredient',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RawAutocomplete<String>(
                  textEditingController: _ctrl,
                  focusNode: _focus,
                  optionsBuilder: (value) => _optionsBuilder(value.text),
                  onSelected: (selection) => _search(selection),
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Try miso, tempeh, kimchi, cassava…',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) {
                        onFieldSubmitted();
                        _search();
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.cardSurface,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                leading: Icon(Icons.restaurant_menu, size: 18, color: AppTheme.glacier),
                                title: Text(option, style: Theme.of(context).textTheme.bodyMedium),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((s) {
                    return ActionChip(
                      label: Text(s),
                      onPressed: () => _search(s),
                      backgroundColor: AppTheme.cardSurface,
                      side: BorderSide(color: AppTheme.cardBorder),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const LoadingState(message: 'Finding similar ingredients…')
          else if (_results.isEmpty)
            const EmptyState(
              icon: Icons.swap_horiz,
              title: 'Search an ingredient',
              message: 'Try miso, tempeh, or kimchi for the cold-start demo.',
            )
          else
            ..._results.map((r) {
              final ingredient = r['ingredient']?.toString() ?? r['similar']?.toString() ?? '';
              final reason = r['reason']?.toString() ?? r['relationship']?.toString() ?? '';
              final source = r['source']?.toString() ?? 'api';
              final confidence = r['confidence'] ?? r['score'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppTheme.phase2Gradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(ingredient, style: Theme.of(context).textTheme.titleMedium),
                            ),
                            if (confidence != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  confidence is num ? (confidence).toStringAsFixed(2) : confidence.toString(),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                                ),
                              ),
                          ],
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(reason, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 6),
                        Text('Source: $source', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// --- Debounce helper for the type-ahead search ---
// Collapses rapid keystrokes into a single backend call. A superseded call
// resolves to null so the caller can keep the previous options.

const Duration _kDebounceDuration = Duration(milliseconds: 250);

typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? timer;
  return (T parameter) async {
    if (timer != null && !timer!.isCompleted) {
      timer!.cancel();
    }
    timer = _DebounceTimer();
    try {
      await timer!.future;
    } on _CancelException {
      return null;
    }
    return function(parameter);
  };
}

class _DebounceTimer {
  _DebounceTimer() {
    _timer = Timer(_kDebounceDuration, _onComplete);
  }

  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() => _completer.complete();

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError(const _CancelException());
  }
}

class _CancelException implements Exception {
  const _CancelException();
}
