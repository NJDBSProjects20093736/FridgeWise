import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recipe_recommendation.dart';
import '../../services/api_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  final RecipeRecommendation summary;

  const RecipeDetailScreen({super.key, required this.recipeId, required this.summary});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final d = await api.getRecipe(widget.recipeId);
    if (mounted) setState(() => _detail = d);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Scaffold(
      appBar: AppBar(title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Match: ${(s.matchPct * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium),
          Text('Score: ${s.finalScore.toStringAsFixed(2)}'),
          if (s.expiringUsed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(
                avatar: const Icon(Icons.warning_amber, size: 18),
                label: Text('Uses expiring: ${s.expiringUsed.join(', ')}'),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Why recommended', style: TextStyle(fontWeight: FontWeight.bold)),
          ...s.whyRecommended.map((w) => ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(w))),
          if (s.missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Missing ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(s.missing.join(', ')),
          ],
          if (_detail != null) ...[
            const SizedBox(height: 16),
            Text('Prep time: ${_detail!['minutes'] ?? '?'} min'),
            Text('Difficulty: ${_detail!['difficulty_level'] ?? ''}'),
          ],
        ],
      ),
    );
  }
}
