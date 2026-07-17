import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meal_plan.dart';
import '../models/recipe_recommendation.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/food_image.dart';
import '../widgets/thrifty_chef_logo.dart';
import 'leftovers_screen.dart';
import 'meal_planner_screen.dart';
import 'recipe_detail_screen.dart';
import 'shopping_list_screen.dart';

enum _MsgKind {
  text,
  welcome,
  recipes,
  mealPlan,
  expiry,
  steps,
  timerOffer,
}

class _ChatMsg {
  final String text;
  final bool fromUser;
  final _MsgKind kind;
  final List<RecipeRecommendation> recipes;
  final List<MealPlanDay> mealDays;
  final List<({String name, int days})> expiry;
  final List<String> steps;
  final int timerMinutes;
  final Set<int> checkedSteps;

  const _ChatMsg(
    this.text, {
    required this.fromUser,
    this.kind = _MsgKind.text,
    this.recipes = const [],
    this.mealDays = const [],
    this.expiry = const [],
    this.steps = const [],
    this.timerMinutes = 0,
    this.checkedSteps = const {},
  });

  _ChatMsg copyWith({Set<int>? checkedSteps}) => _ChatMsg(
        text,
        fromUser: fromUser,
        kind: kind,
        recipes: recipes,
        mealDays: mealDays,
        expiry: expiry,
        steps: steps,
        timerMinutes: timerMinutes,
        checkedSteps: checkedSteps ?? this.checkedSteps,
      );
}

class AssistantScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onClose;

  const AssistantScreen({super.key, this.embedded = false, this.onClose});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late final AnimationController _pulse;
  bool _thinking = false;
  bool _showWelcomeCards = true;
  RecipeRecommendation? _activeRecipe;

  // Docked kitchen timer
  Timer? _timer;
  int _timerRemaining = 0;
  bool _timerRunning = false;

  final _msgs = <_ChatMsg>[
    const _ChatMsg(
      'Hi — I am your ThriftyChef cooking assistant. Pick a quick action or ask me anything about cooking, expiry, or meal planning.',
      fromUser: false,
      kind: _MsgKind.welcome,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  List<({String label, String prompt, IconData icon})> get _smartChips {
    if (_timerRunning) {
      return [
        (label: 'Stop timer', prompt: '__stop_timer__', icon: Icons.timer_off_outlined),
        (label: 'Next step', prompt: 'What is the next step?', icon: Icons.skip_next_outlined),
      ];
    }
    if (_activeRecipe != null) {
      return [
        (label: 'Next step', prompt: 'Walk me through the steps for ${_activeRecipe!.name}', icon: Icons.checklist_rtl),
        (label: 'What do I need?', prompt: 'What ingredients am I missing for ${_activeRecipe!.name}?', icon: Icons.list_alt),
        (label: 'Timer 10 min', prompt: '__timer_10__', icon: Icons.timer_outlined),
        (label: 'Add to shopping', prompt: 'Add missing ingredients for ${_activeRecipe!.name} to shopping list', icon: Icons.add_shopping_cart),
      ];
    }
    return [
      (label: 'Expiring soon', prompt: 'What expires soon?', icon: Icons.schedule),
      (label: 'Under 20 min', prompt: 'Dinner in under 20 minutes', icon: Icons.bolt_outlined),
      (label: '3-day plan', prompt: 'Generate a 3-day meal plan', icon: Icons.calendar_view_week),
      (label: 'Shopping', prompt: 'Add missing meal-plan items to shopping list', icon: Icons.shopping_basket_outlined),
    ];
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    if (text == '__stop_timer__') {
      _stopTimer();
      setState(() => _msgs.add(const _ChatMsg('Timer stopped.', fromUser: false)));
      _scrollToEnd();
      return;
    }
    if (text.startsWith('__timer_')) {
      final mins = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
      _startTimer(mins);
      setState(() {
        _msgs.add(_ChatMsg('Started a $mins minute timer. It stays docked at the top while you cook.', fromUser: false));
      });
      _scrollToEnd();
      return;
    }

    setState(() {
      _msgs.add(_ChatMsg(text, fromUser: true));
      _ctrl.clear();
      _showWelcomeCards = false;
      _thinking = true;
    });
    _scrollToEnd();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final state = context.read<AppState>();
    final q = text.toLowerCase();

    try {
      if ((q.contains('plan') && (q.contains('week') || q.contains('meal') || q.contains('3') || q.contains('three'))) ||
          q.contains('meal plan')) {
        await state.generateMealPlan();
        final days = state.mealPlan.take(q.contains('7') || q.contains('week') ? 7 : 3).toList();
        setState(() {
          _msgs.add(_ChatMsg(
            'Here is a ${days.length}-day meal plan from your fridge. Swipe the cards or open the full planner.',
            fromUser: false,
            kind: _MsgKind.mealPlan,
            mealDays: days,
          ));
        });
      } else if (q.contains('shopping') || q.contains('buy') || q.contains('add missing')) {
        if (_activeRecipe != null && q.contains(_activeRecipe!.name.toLowerCase().split(' ').first)) {
          final n = await state.addMissingToShoppingList(
            _activeRecipe!.missing,
            recipeName: _activeRecipe!.name,
          );
          setState(() {
            _msgs.add(_ChatMsg(
              n == 0
                  ? 'Nothing new to add — shopping list already covers gaps for ${_activeRecipe!.name}.'
                  : 'Added $n missing ingredients for ${_activeRecipe!.name} to your shopping list.',
              fromUser: false,
            ));
          });
        } else {
          final n = await state.addMealPlanMissingToShoppingList();
          setState(() {
            _msgs.add(_ChatMsg(
              n == 0
                  ? 'Your shopping list already covers current meal-plan gaps.'
                  : 'Added $n missing meal-plan items to your shopping list.',
              fromUser: false,
            ));
          });
        }
      } else if (q.contains('expir') || q.contains('waste') || q.contains('soon')) {
        final urgent = state.fridge.where((f) => f.daysToExpiry <= 3).toList()
          ..sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
        setState(() {
          _msgs.add(_ChatMsg(
            urgent.isEmpty
                ? 'Nothing critical is expiring in the next 3 days. Nice work keeping waste down.'
                : 'These ingredients need attention soon — tap Leftovers to rescue them.',
            fromUser: false,
            kind: urgent.isEmpty ? _MsgKind.text : _MsgKind.expiry,
            expiry: urgent
                .map((f) => (name: f.ingredientName, days: f.daysToExpiry))
                .toList(),
          ));
          if (urgent.isNotEmpty) {
            _msgs.add(const _ChatMsg(
              'Simmer tip: use the soonest items first. Want a 15-minute timer while you prep?',
              fromUser: false,
              kind: _MsgKind.timerOffer,
              timerMinutes: 15,
            ));
          }
        });
      } else if (q.contains('leftover')) {
        setState(() {
          _msgs.add(const _ChatMsg('Opening leftover ideas ranked by fridge match…', fromUser: false));
        });
        widget.onClose?.call();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => const LeftoversScreen()),
          );
        });
      } else if (q.contains('step') || q.contains('walk me') || q.contains('how do i cook') || q.contains('instructions')) {
        final recipe = _activeRecipe ??
            (state.recommendations.isEmpty ? null : state.recommendations.first);
        if (recipe == null) {
          if (state.recommendations.isEmpty) await state.loadRecommendations();
        }
        final r = _activeRecipe ??
            (state.recommendations.isNotEmpty ? state.recommendations.first : null);
        if (r == null) {
          setState(() {
            _msgs.add(const _ChatMsg(
              'I need a recipe first — ask for a dinner idea, then I can walk you through the steps.',
              fromUser: false,
            ));
          });
        } else {
          _activeRecipe = r;
          final steps = _syntheticSteps(r);
          setState(() {
            _msgs.add(_ChatMsg(
              'Cooking guide for ${r.name}. Check steps off as you go.',
              fromUser: false,
              kind: _MsgKind.steps,
              steps: steps,
              recipes: [r],
            ));
            _msgs.add(_ChatMsg(
              'Need a timer while something simmers?',
              fromUser: false,
              kind: _MsgKind.timerOffer,
              timerMinutes: r.prepTimeMinutes > 0 && r.prepTimeMinutes <= 45 ? (r.prepTimeMinutes ~/ 2).clamp(5, 20) : 10,
            ));
          });
        }
      } else if (q.contains('missing') || q.contains('what do i need') || q.contains('ingredients')) {
        final r = _activeRecipe;
        if (r == null) {
          setState(() {
            _msgs.add(const _ChatMsg(
              'Pick a recipe first, then I can list what you still need.',
              fromUser: false,
            ));
          });
        } else if (r.missing.isEmpty) {
          setState(() {
            _msgs.add(_ChatMsg(
              'You already have everything for ${r.name}. Ready to cook!',
              fromUser: false,
            ));
          });
        } else {
          setState(() {
            _msgs.add(_ChatMsg(
              'Still needed for ${r.name}:\n• ${r.missing.take(8).join('\n• ')}',
              fromUser: false,
              recipes: [r],
              kind: _MsgKind.recipes,
            ));
          });
        }
      } else if (q.contains('timer') || q.contains('simmer') || RegExp(r'\d+\s*min').hasMatch(q)) {
        final match = RegExp(r'(\d+)\s*min').firstMatch(q);
        final mins = int.tryParse(match?.group(1) ?? '') ?? 10;
        setState(() {
          _msgs.add(_ChatMsg(
            'Ready when you are — start a $mins minute kitchen timer.',
            fromUser: false,
            kind: _MsgKind.timerOffer,
            timerMinutes: mins,
          ));
        });
      } else {
        if (state.recommendations.isEmpty) await state.loadRecommendations();
        final hits = state.searchNaturalLanguage(text);
        if (hits.isEmpty) {
          setState(() {
            _msgs.add(const _ChatMsg(
              'I could not find a strong match. Try “quick dinner”, “healthy under 20 minutes”, or add more fridge items.',
              fromUser: false,
            ));
          });
        } else {
          final top = hits.take(4).toList();
          _activeRecipe = top.first;
          setState(() {
            _msgs.add(_ChatMsg(
              'Here are fridge-friendly ideas. Tap a card to open the recipe.',
              fromUser: false,
              kind: _MsgKind.recipes,
              recipes: top,
            ));
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _thinking = false);
        _scrollToEnd();
      }
    }
  }

  List<String> _syntheticSteps(RecipeRecommendation r) {
    final missingHint = r.missing.isEmpty
        ? 'Confirm you have everything from the fridge.'
        : 'Gather missing items if needed: ${r.missing.take(3).join(', ')}.';
    return [
      'Wash hands and clear a clean workspace.',
      missingHint,
      if (r.expiringUsed.isNotEmpty) 'Prioritise: ${r.expiringUsed.take(3).join(', ')} (expiring soon).',
      'Prep vegetables and proteins — keep scraps for stock if useful.',
      'Cook the main components (about ${r.prepTimeMinutes > 0 ? r.prepTimeMinutes : 25} minutes total).',
      'Taste, season, and plate. Save leftovers for tomorrow if you like batch cooking.',
    ];
  }

  void _startTimer(int minutes) {
    _timer?.cancel();
    setState(() {
      _timerRemaining = minutes * 60;
      _timerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_timerRemaining <= 1) {
        t.cancel();
        setState(() {
          _timerRunning = false;
          _timerRemaining = 0;
          _msgs.add(const _ChatMsg('⏰ Timer done — check your dish!', fromUser: false));
        });
        _scrollToEnd();
        return;
      }
      setState(() => _timerRemaining -= 1);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerRemaining = 0;
    });
  }

  void _openVoiceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.cardSurface,
      builder: (ctx) {
        final options = [
          'What expires soon?',
          'Dinner in under 20 minutes',
          'Generate a 3-day meal plan',
          'Walk me through the steps',
          'Set a timer for 10 minutes',
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.mic, color: AppTheme.primaryGreen),
                    const SizedBox(width: 10),
                    Text('Hands-free kitchen commands', style: Theme.of(ctx).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Voice transcription needs device mic permission in a full release. For now, tap a command as if you spoke it.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                ...options.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _send(o);
                      },
                      child: Align(alignment: Alignment.centerLeft, child: Text(o)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerLabel =
        '${(_timerRemaining ~/ 60).toString().padLeft(2, '0')}:${(_timerRemaining % 60).toString().padLeft(2, '0')}';

    final body = Column(
      children: [
        if (_timerRunning)
          Material(
            color: AppTheme.lightGreen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.timer, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  Text(
                    'Kitchen timer  $timerLabel',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textDark),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _stopTimer, child: const Text('Stop')),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: _msgs.length + (_thinking ? 1 : 0),
            itemBuilder: (_, i) {
              if (_thinking && i == _msgs.length) {
                return _ThinkingRow(pulse: _pulse);
              }
              final m = _msgs[i];
              return _MessageBlock(
                msg: m,
                showQuickActions: m.kind == _MsgKind.welcome && _showWelcomeCards,
                pulse: _pulse,
                onQuickAction: _send,
                onOpenRecipe: (r) {
                  setState(() => _activeRecipe = r);
                  widget.onClose?.call();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.recipeId, summary: r)),
                    );
                  });
                },
                onAddShopping: (r) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final n = await context.read<AppState>().addMissingToShoppingList(
                        r.missing,
                        recipeName: r.name,
                      );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        n == 0 ? 'Shopping list already up to date' : 'Added $n items to shopping list',
                      ),
                    ),
                  );
                },
                onStartTimer: _startTimer,
                onToggleStep: (msgIndex, stepIndex) {
                  setState(() {
                    final cur = _msgs[msgIndex];
                    final next = Set<int>.from(cur.checkedSteps);
                    next.contains(stepIndex) ? next.remove(stepIndex) : next.add(stepIndex);
                    _msgs[msgIndex] = cur.copyWith(checkedSteps: next);
                  });
                },
                msgIndex: i,
                onOpenLeftovers: () {
                  widget.onClose?.call();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const LeftoversScreen()),
                    );
                  });
                },
                onOpenPlanner: () {
                  widget.onClose?.call();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const MealPlannerScreen()),
                    );
                  });
                },
              );
            },
          ),
        ),
        _SmartChipBar(
          chips: _smartChips,
          onTap: (prompt) {
            if (prompt.startsWith('__')) {
              _send(prompt);
            } else {
              _ctrl.text = prompt;
              _send(prompt);
            }
          },
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Voice / hands-free',
                  onPressed: _openVoiceSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.lightGreen,
                    foregroundColor: AppTheme.primaryGreen,
                  ),
                  icon: const Icon(Icons.mic_none_outlined),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ask anything — recipes, timers, plans…',
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: () => _send(_ctrl.text),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Material(
        color: AppTheme.background,
        child: Column(
          children: [
            _OverlayHeader(
              onClose: widget.onClose,
              onPlanner: () {
                widget.onClose?.call();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const MealPlannerScreen()),
                  );
                });
              },
              onShopping: () {
                widget.onClose?.call();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                  );
                });
              },
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 0,
        title: const Text('Cooking assistant'),
        actions: [
          IconButton(
            tooltip: 'Meal planner',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlannerScreen())),
            icon: const Icon(Icons.calendar_month_outlined, size: 22),
          ),
          IconButton(
            tooltip: 'Shopping list',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
            icon: const Icon(Icons.shopping_basket_outlined, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  final VoidCallback? onClose;
  final VoidCallback onPlanner;
  final VoidCallback onShopping;

  const _OverlayHeader({
    required this.onClose,
    required this.onPlanner,
    required this.onShopping,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardSurface,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
            const ChefHatIcon(size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cooking assistant',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              tooltip: 'Meal planner',
              visualDensity: VisualDensity.compact,
              onPressed: onPlanner,
              icon: const Icon(Icons.calendar_month_outlined, size: 22),
            ),
            IconButton(
              tooltip: 'Shopping list',
              visualDensity: VisualDensity.compact,
              onPressed: onShopping,
              icon: const Icon(Icons.shopping_basket_outlined, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartChipBar extends StatelessWidget {
  final List<({String label, String prompt, IconData icon})> chips;
  final ValueChanged<String> onTap;

  const _SmartChipBar({required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          return ActionChip(
            avatar: Icon(c.icon, size: 16, color: AppTheme.primaryGreen),
            label: Text(c.label),
            onPressed: () => onTap(c.prompt),
            side: BorderSide(color: AppTheme.cardBorder),
            backgroundColor: AppTheme.cardSurface,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          );
        },
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  final AnimationController pulse;
  const _ThinkingRow({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChefAvatar(pulse: pulse, thinking: true),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Text('Thinking…', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChefAvatar extends StatelessWidget {
  final AnimationController pulse;
  final bool thinking;
  const _ChefAvatar({required this.pulse, this.thinking = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final scale = thinking ? 0.92 + (pulse.value * 0.12) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.35)),
              boxShadow: thinking
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.2 + pulse.value * 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: const Center(child: ChefHatIcon(size: 22)),
          ),
        );
      },
    );
  }
}

class _MessageBlock extends StatelessWidget {
  final _ChatMsg msg;
  final int msgIndex;
  final bool showQuickActions;
  final AnimationController pulse;
  final ValueChanged<String> onQuickAction;
  final ValueChanged<RecipeRecommendation> onOpenRecipe;
  final ValueChanged<RecipeRecommendation> onAddShopping;
  final ValueChanged<int> onStartTimer;
  final void Function(int msgIndex, int stepIndex) onToggleStep;
  final VoidCallback onOpenLeftovers;
  final VoidCallback onOpenPlanner;

  const _MessageBlock({
    required this.msg,
    required this.msgIndex,
    required this.showQuickActions,
    required this.pulse,
    required this.onQuickAction,
    required this.onOpenRecipe,
    required this.onAddShopping,
    required this.onStartTimer,
    required this.onToggleStep,
    required this.onOpenLeftovers,
    required this.onOpenPlanner,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(msg.text, style: const TextStyle(color: Colors.white, height: 1.35)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChefAvatar(pulse: pulse),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text(msg.text, style: TextStyle(color: AppTheme.textDark, height: 1.4)),
                ),
                if (showQuickActions) ...[
                  const SizedBox(height: 12),
                  _QuickActionGrid(onTap: onQuickAction),
                ],
                if (msg.kind == _MsgKind.recipes && msg.recipes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _RecipeCarousel(
                    recipes: msg.recipes,
                    onOpen: onOpenRecipe,
                    onAddShopping: onAddShopping,
                  ),
                ],
                if (msg.kind == _MsgKind.mealPlan && msg.mealDays.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _MealPlanCarousel(
                    days: msg.mealDays,
                    onOpen: (r) => onOpenRecipe(r),
                    onOpenPlanner: onOpenPlanner,
                  ),
                ],
                if (msg.kind == _MsgKind.expiry && msg.expiry.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ExpiryCard(items: msg.expiry, onLeftovers: onOpenLeftovers),
                ],
                if (msg.kind == _MsgKind.steps && msg.steps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _StepsChecklist(
                    steps: msg.steps,
                    checked: msg.checkedSteps,
                    onToggle: (i) => onToggleStep(msgIndex, i),
                  ),
                ],
                if (msg.kind == _MsgKind.timerOffer) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () => onStartTimer(msg.timerMinutes > 0 ? msg.timerMinutes : 10),
                    icon: const Icon(Icons.timer_outlined),
                    label: Text('Start ${msg.timerMinutes > 0 ? msg.timerMinutes : 10} min timer'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _QuickActionGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        title: "What's expiring?",
        subtitle: 'Show ingredients that expire soon',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFF59E0B),
        prompt: 'What expires soon?',
      ),
      (
        title: 'Fast meals',
        subtitle: 'Dinner in under 20 minutes',
        icon: Icons.timer_outlined,
        color: AppTheme.primaryGreen,
        prompt: 'Dinner in under 20 minutes',
      ),
      (
        title: 'Meal plan',
        subtitle: 'Generate a 3-day meal plan',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF6366F1),
        prompt: 'Generate a 3-day meal plan',
      ),
      (
        title: 'Leftovers',
        subtitle: 'Rescue recipes from the fridge',
        icon: Icons.soup_kitchen_outlined,
        color: AppTheme.roseAccent,
        prompt: 'Show leftover ideas',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 420;
        final children = cards
            .map(
              (c) => _QuickActionCard(
                title: c.title,
                subtitle: c.subtitle,
                icon: c.icon,
                accent: c.color,
                onTap: () => onTap(c.prompt),
              ),
            )
            .toList();
        if (wide) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: children.map((w) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: w)).toList(),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.25)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeCarousel extends StatelessWidget {
  final List<RecipeRecommendation> recipes;
  final ValueChanged<RecipeRecommendation> onOpen;
  final ValueChanged<RecipeRecommendation> onAddShopping;

  const _RecipeCarousel({
    required this.recipes,
    required this.onOpen,
    required this.onAddShopping,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final r = recipes[i];
          return SizedBox(
            width: 210,
            child: Material(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onOpen(r),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FoodImage(label: r.name, height: 110, borderRadius: BorderRadius.zero),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${(r.matchPct * 100).round()}% match · ${r.prepTimeMinutes > 0 ? '${r.prepTimeMinutes} min' : 'Flexible'}',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 8),
                            if (r.missingCount > 0)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => onAddShopping(r),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text('Add missing', style: TextStyle(fontSize: 12)),
                                ),
                              )
                            else
                              Text(
                                'All in fridge',
                                style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MealPlanCarousel extends StatelessWidget {
  final List<MealPlanDay> days;
  final ValueChanged<RecipeRecommendation> onOpen;
  final VoidCallback onOpenPlanner;

  const _MealPlanCarousel({
    required this.days,
    required this.onOpen,
    required this.onOpenPlanner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final d = days[i];
              final r = d.recipe;
              return SizedBox(
                width: 180,
                child: Material(
                  color: AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: r == null ? null : () => onOpen(r),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FoodImage(
                            label: r?.name ?? d.dayLabel,
                            height: 96,
                            borderRadius: BorderRadius.zero,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.dayLabel, style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                  r?.name ?? 'No recipe',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onOpenPlanner,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open full meal planner'),
        ),
      ],
    );
  }
}

class _ExpiryCard extends StatelessWidget {
  final List<({String name, int days})> items;
  final VoidCallback onLeftovers;

  const _ExpiryCard({required this.items, required this.onLeftovers});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final it in items.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: it.days <= 1 ? AppTheme.dangerRed : AppTheme.warningOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(
                    it.days <= 0 ? 'Today' : '${it.days}d',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: it.days <= 1 ? AppTheme.dangerRed : AppTheme.warningOrange,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          FilledButton.tonal(
            onPressed: onLeftovers,
            child: const Text('Open leftover generator'),
          ),
        ],
      ),
    );
  }
}

class _StepsChecklist extends StatelessWidget {
  final List<String> steps;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  const _StepsChecklist({
    required this.steps,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final done = checked.length.clamp(0, steps.length);
    final progress = steps.isEmpty ? 0.0 : done / steps.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Step $done of ${steps.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${(progress * 100).round()}%', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.lightGreen,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: checked.contains(i),
              onChanged: (_) => onToggle(i),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                steps[i],
                style: TextStyle(
                  decoration: checked.contains(i) ? TextDecoration.lineThrough : null,
                  color: checked.contains(i) ? AppTheme.textMuted : AppTheme.textDark,
                  height: 1.3,
                  fontSize: 13.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
