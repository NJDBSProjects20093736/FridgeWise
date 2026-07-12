import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool center;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? AppTheme.pagePadding(context);
    final content = Padding(padding: resolvedPadding, child: child);
    final constrained = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? AppTheme.maxContentWidth),
      child: content,
    );
    if (!center) return constrained;
    return Align(alignment: Alignment.topCenter, child: constrained);
  }
}

bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width > 900;
bool isDesktopLayout(BuildContext context) => MediaQuery.sizeOf(context).width > 1100;
