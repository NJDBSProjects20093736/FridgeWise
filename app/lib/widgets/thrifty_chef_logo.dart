import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Official ThriftyChef lockup — transparent wordmark + optional tagline.
class ThriftyChefLogo extends StatelessWidget {
  final double height;
  final bool showTagline;

  const ThriftyChefLogo({
    super.key,
    this.height = 96,
    this.showTagline = true,
  });

  /// App bar — compact wordmark.
  const ThriftyChefLogo.compact({super.key})
      : height = 48,
        showTagline = false;

  /// Onboarding / splash — larger wordmark with tagline.
  const ThriftyChefLogo.header({super.key})
      : height = 140,
        showTagline = true;

  static Color get teal => AppTheme.glacierDeep;
  static Color get coral => AppTheme.roseAccent;

  static const wordmarkAsset = 'assets/branding/thriftychef_wordmark.png';
  static const hatAsset = 'assets/branding/thriftychef_hat_icon.png';

  @override
  Widget build(BuildContext context) {
    final markHeight = showTagline ? height * 0.78 : height;
    final tagSize = (height * 0.09).clamp(8.0, 12.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Transparent PNG — blends with AppBar / page background.
          Image.asset(
            wordmarkAsset,
            height: markHeight,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _FallbackWordmark(height: markHeight),
          ),
          if (showTagline) ...[
            SizedBox(height: height * 0.06),
            Text(
              'SMART SAVINGS. DELICIOUS MEALS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: tagSize,
                fontWeight: FontWeight.w700,
                color: teal,
                letterSpacing: 1.7,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FallbackWordmark extends StatelessWidget {
  final double height;
  const _FallbackWordmark({required this.height});

  @override
  Widget build(BuildContext context) {
    final wordSize = height * 0.28;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChefHatIcon(size: height * 0.45),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Thrifty',
                style: TextStyle(
                  fontSize: wordSize,
                  fontWeight: FontWeight.w800,
                  color: ThriftyChefLogo.teal,
                  height: 1,
                ),
              ),
              TextSpan(
                text: 'Chef',
                style: TextStyle(
                  fontSize: wordSize,
                  fontWeight: FontWeight.w800,
                  color: ThriftyChefLogo.coral,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Brand chef-hat mark from the logo artwork (transparent PNG).
class ChefBrandMark extends StatelessWidget {
  final double size;
  final Color? color;
  const ChefBrandMark({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      ThriftyChefLogo.hatAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => CustomPaint(
        size: Size(size, size),
        painter: _BrandHatPainter(color: color ?? ThriftyChefLogo.coral),
      ),
    );
    if (color == null || color == ThriftyChefLogo.coral) return img;
    // Tint for white-on-teal FAB etc.
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      child: img,
    );
  }
}

class ChefHatIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const ChefHatIcon({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) => ChefBrandMark(size: size, color: color);
}

/// Fallback vector hat if the asset fails to load.
class _BrandHatPainter extends CustomPainter {
  final Color color;
  _BrandHatPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sw = (h * 0.065).clamp(2.0, 3.2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final crown = Path()
      ..moveTo(w * 0.16, h * 0.52)
      ..cubicTo(w * 0.08, h * 0.42, w * 0.10, h * 0.16, w * 0.30, h * 0.12)
      ..cubicTo(w * 0.42, h * 0.03, w * 0.52, h * 0.03, w * 0.64, h * 0.10)
      ..cubicTo(w * 0.82, h * 0.08, w * 0.92, h * 0.22, w * 0.88, h * 0.40)
      ..cubicTo(w * 0.90, h * 0.48, w * 0.82, h * 0.52, w * 0.78, h * 0.52)
      ..close();
    canvas.drawPath(crown, stroke);

    final bandTop = h * 0.52;
    final bandBottom = h * 0.78;
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.14, bandTop, w * 0.86, bandBottom, Radius.circular(h * 0.07)),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandHatPainter oldDelegate) => oldDelegate.color != color;
}
