import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'leftovers_screen.dart';
import 'meal_planner_screen.dart';
import 'recipe_detail_screen.dart';
import 'shopping_list_screen.dart';

class _ChatMsg {
  final String text;
  final bool fromUser;
  const _ChatMsg(this.text, {required this.fromUser});
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _msgs = <_ChatMsg>[
    const _ChatMsg(
      'Hi — I am your ThriftyChef cooking assistant. Ask things like “what can I cook tonight?”, “plan my week”, “what expires soon?”, or “healthy dinner under 20 minutes”.',
      fromUser: false,
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    setState(() {
      _msgs.add(_ChatMsg(text, fromUser: true));
      _ctrl.clear();
    });

    final state = context.read<AppState>();
    final q = text.toLowerCase();
    String reply;

    if (q.contains('plan') && (q.contains('week') || q.contains('meal'))) {
      await state.generateMealPlan();
      reply = 'I generated a 7-day meal plan using your fridge. Open Meal Planner to review it, or ask me to add missing items to your shopping list.';
      if (mounted) {
        setState(() => _msgs.add(_ChatMsg(reply, fromUser: false)));
        return;
      }
    } else if (q.contains('shopping') || q.contains('buy')) {
      final n = await state.addMealPlanMissingToShoppingList();
      reply = n == 0
          ? 'Your shopping list already covers the current meal-plan gaps. Open Shopping list anytime from the basket icon.'
          : 'Added $n missing meal-plan items to your shopping list.';
    } else if (q.contains('expir') || q.contains('waste')) {
      final urgent = state.fridge.where((f) => f.daysToExpiry <= 2).toList();
      reply = urgent.isEmpty
          ? 'Nothing critical is expiring in the next 2 days. Nice work.'
          : 'Expiring soon: ${urgent.map((f) => '${f.ingredientName} (${f.daysToExpiry}d)').join(', ')}. Try Leftover Generator for recipes that use them.';
    } else if (q.contains('leftover')) {
      reply = 'Opening leftover ideas ranked by fridge match…';
      setState(() => _msgs.add(_ChatMsg(reply, fromUser: false)));
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeftoversScreen()));
      }
      return;
    } else {
      if (state.recommendations.isEmpty) await state.loadRecommendations();
      final hits = state.searchNaturalLanguage(text);
      if (hits.isEmpty) {
        reply = 'I could not find a strong match. Try “quick dinner”, “healthy under 20 minutes”, or add more fridge items.';
      } else {
        final top = hits.first;
        reply =
            'Top idea: ${top.name} (${(top.matchPct * 100).round()}% fridge match, ${top.prepTimeMinutes} min). '
            'Agents: Expiry + Match + Nutrition. Tap below to open it, or ask another question.';
        setState(() {
          _msgs.add(_ChatMsg(reply, fromUser: false));
          _msgs.add(_ChatMsg('OPEN_RECIPE:${top.recipeId}:${top.name}', fromUser: false));
        });
        return;
      }
    }

    if (mounted) setState(() => _msgs.add(_ChatMsg(reply, fromUser: false)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cooking assistant'),
        actions: [
          IconButton(
            tooltip: 'Meal planner',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlannerScreen())),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Shopping list',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
            icon: const Icon(Icons.shopping_basket_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                if (!m.fromUser && m.text.startsWith('OPEN_RECIPE:')) {
                  final parts = m.text.split(':');
                  final id = int.tryParse(parts[1]) ?? 0;
                  final name = parts.skip(2).join(':');
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final state = context.read<AppState>();
                        final rec = state.recommendations.where((r) => r.recipeId == id);
                        if (rec.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipeId: id, summary: rec.first),
                          ),
                        );
                      },
                      icon: const Icon(Icons.restaurant),
                      label: Text('Open $name'),
                    ),
                  );
                }
                return Align(
                  alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
                    decoration: BoxDecoration(
                      color: m.fromUser ? AppTheme.primaryGreen : AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(color: m.fromUser ? Colors.white : AppTheme.textDark, height: 1.35),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask for a recipe, meal plan, or expiry help…',
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _send(_ctrl.text),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
