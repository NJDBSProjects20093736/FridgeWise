import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'responsive_container.dart';

class AppScaffold extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool scrollable;
  final bool showHeader;
  final Widget? floatingAction;

  const AppScaffold({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.scrollable = true,
    this.showHeader = true,
    this.floatingAction,
  });

  @override
  Widget build(BuildContext context) {
    final body = ResponsiveContainer(
      child: scrollable
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeader && title != null) _PageHeader(title: title!, subtitle: subtitle),
                  child,
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHeader && title != null) _PageHeader(title: title!, subtitle: subtitle),
                Expanded(child: child),
              ],
            ),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: floatingAction,
      body: body,
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _PageHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }
}

class ApiStatusIndicator extends StatelessWidget {
  const ApiStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final apiOk = context.select<AppState, bool>((s) => s.apiOk);
    final color = apiOk ? AppTheme.goodTeal : AppTheme.dangerRed;
    final label = apiOk ? 'Connected' : 'Offline';

    return Tooltip(
      message: apiOk ? 'API connected' : 'Using local fallback / API offline',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class FridgeWiseLogoHeader extends StatelessWidget {
  final String? subtitle;
  final bool compact;

  const FridgeWiseLogoHeader({super.key, this.subtitle, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: compact ? 56 : 72,
          height: compact ? 56 : 72,
          decoration: BoxDecoration(
            gradient: AppTheme.glacierHeroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppTheme.glacier.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.ac_unit, color: Colors.white, size: 36),
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          'FridgeWise AI',
          style: TextStyle(
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.glacierDeep,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ],
    );
  }
}
