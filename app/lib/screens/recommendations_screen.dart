import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../models/recipe_recommendation.dart';
import '../../services/api_service.dart';
import 'recipe_detail_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<RecipeRecommendation>? _recipes;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final recs = await api.recommend(userId: ApiConfig.demoUserId, k: 10);
      if (mounted) setState(() => _recipes = recs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _recipes?.length ?? 0,
                  itemBuilder: (context, i) {
                    final r = _recipes![i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${(r.matchPct * 100).toStringAsFixed(0)}% fridge match'
                          '${r.expiringUsed.isNotEmpty ? ' · uses expiring items' : ''}',
                        ),
                        trailing: r.expiringUsed.isNotEmpty
                            ? const Icon(Icons.schedule, color: Colors.orange)
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipeId: r.recipeId, summary: r),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
