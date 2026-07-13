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
bool isNarrowLayout(BuildContext context) => MediaQuery.sizeOf(context).width < 480;
bool isTabletLayout(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= 480 && w <= 900;
}

int responsiveColumns(BuildContext context, {int max = 2}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1000) return max;
  if (w >= 640) return 2;
  return 1;
}

double responsiveCarouselItemWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 900) return 240;
  if (w >= 480) return w * 0.52;
  return w * 0.72;
}
