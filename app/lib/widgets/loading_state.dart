import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'thrifty_chef_logo.dart';

class LoadingState extends StatelessWidget {
  final String? message;
  final bool showBrand;

  const LoadingState({super.key, this.message, this.showBrand = false});

  /// Full-screen bootstrap / cold start.
  const LoadingState.bootstrap({super.key, this.message}) : showBrand = true;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBrand) ...[
              const ThriftyChefLogo.header(),
              const SizedBox(height: 28),
            ] else ...[
              const ChefHatIcon(size: 40),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: AppTheme.primaryGreen,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingSkeletonList extends StatelessWidget {
  final int count;

  const LoadingSkeletonList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SkeletonCard(delay: i * 80),
        );
      }),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final int delay;

  const _SkeletonCard({required this.delay});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final opacity = 0.4 + (_controller.value * 0.3);
        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.cardBorder.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}

class NutritionMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const NutritionMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryGreen),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
