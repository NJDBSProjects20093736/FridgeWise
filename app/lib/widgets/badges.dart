import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScoreBadge extends StatelessWidget {
  final double matchPct;
  final double size;

  const ScoreBadge({super.key, required this.matchPct, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final pct = (matchPct * 100).clamp(0, 100);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct / 100,
            strokeWidth: 4,
            backgroundColor: AppTheme.cardBorder,
            color: AppTheme.primaryGreen,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                ),
              ),
              Text('match', style: TextStyle(fontSize: size * 0.14, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class SafetyBadge extends StatelessWidget {
  final bool safe;
  final bool compact;

  const SafetyBadge({super.key, required this.safe, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!safe) {
      return _chip(
        icon: Icons.warning_amber_rounded,
        label: compact ? 'Check' : 'Review safety',
        bg: AppTheme.warningOrange.withValues(alpha: 0.12),
        fg: AppTheme.warningOrange,
      );
    }
    return _chip(
      icon: Icons.verified_user,
      label: 'Safe',
      bg: AppTheme.iceLight,
      fg: AppTheme.glacier,
    );
  }

  Widget _chip({required IconData icon, required String label, required Color bg, required Color fg}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

class ExpiryChip extends StatelessWidget {
  final int count;
  final List<String>? items;

  const ExpiryChip({super.key, required this.count, this.items});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'Uses expiring item' : 'Uses $count expiring';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 14, color: AppTheme.warningOrange),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warningOrange)),
        ],
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const TagChip({super.key, required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}
