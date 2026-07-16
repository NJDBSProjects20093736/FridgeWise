import 'package:flutter/material.dart';
import '../models/fridge_item.dart';
import '../theme/app_theme.dart';

class FridgeHealthScore {
  final int score;
  final String label;
  final String summary;
  final Color color;
  final int freshCount;
  final int soonCount;
  final int criticalCount;

  const FridgeHealthScore({
    required this.score,
    required this.label,
    required this.summary,
    required this.color,
    required this.freshCount,
    required this.soonCount,
    required this.criticalCount,
  });

  factory FridgeHealthScore.from(List<FridgeItem> fridge) {
    if (fridge.isEmpty) {
      return FridgeHealthScore(
        score: 0,
        label: 'Empty',
        summary: 'Add ingredients to see freshness and waste risk.',
        color: AppTheme.glacier,
        freshCount: 0,
        soonCount: 0,
        criticalCount: 0,
      );
    }

    final critical = fridge.where((f) => f.daysToExpiry <= 1).length;
    final soon = fridge.where((f) => f.daysToExpiry > 1 && f.daysToExpiry <= 5).length;
    final fresh = fridge.where((f) => f.daysToExpiry > 5).length;
    final total = fridge.length;

    // Weighted freshness: fresh=1.0, soon=0.55, critical=0.15
    final weighted = (fresh * 1.0 + soon * 0.55 + critical * 0.15) / total;
    final score = (weighted * 100).round().clamp(0, 100);

    String label;
    Color color;
    if (score >= 75) {
      label = 'Healthy';
      color = AppTheme.goodTeal;
    } else if (score >= 50) {
      label = 'Watch closely';
      color = AppTheme.warningOrange;
    } else {
      label = 'At risk';
      color = AppTheme.dangerRed;
    }

    final summary = critical > 0
        ? '$critical item${critical == 1 ? '' : 's'} need cooking soon to avoid waste.'
        : soon > 0
            ? '$soon item${soon == 1 ? '' : 's'} expire within 5 days — plan a meal.'
            : 'Everything looks fresh. Nice work keeping waste low.';

    return FridgeHealthScore(
      score: score,
      label: label,
      summary: summary,
      color: color,
      freshCount: fresh,
      soonCount: soon,
      criticalCount: critical,
    );
  }
}
