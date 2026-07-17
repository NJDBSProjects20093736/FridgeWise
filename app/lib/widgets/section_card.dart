import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? helper;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SectionCard({
    super.key,
    required this.title,
    this.helper,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (helper != null) ...[
              const SizedBox(height: 4),
              Text(helper!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget>? badges;
  final Widget? trailing;

  const HeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.badges,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return Container(
      decoration: AppTheme.heroDecoration(),
      padding: EdgeInsets.all(narrow ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _heroIcon(),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 12),
                _heroText(context),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroIcon(),
                const SizedBox(width: 14),
                Expanded(child: _heroText(context)),
                if (trailing != null) trailing!,
              ],
            ),
          if (badges != null && badges!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: badges!),
          ],
        ],
      ),
    );
  }

  Widget _heroIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
      ),
      child: Icon(Icons.auto_awesome, color: AppTheme.glacier),
    );
  }

  Widget _heroText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
      ],
    );
  }
}

class InfoBadge extends StatelessWidget {
  final String label;
  final Color? background;
  final Color? foreground;
  final IconData? icon;

  const InfoBadge({
    super.key,
    required this.label,
    this.background,
    this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? AppTheme.cardSurface;
    final fg = foreground ?? AppTheme.glacier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool expand;

  const SummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
    return expand ? Expanded(child: card) : card;
  }
}
