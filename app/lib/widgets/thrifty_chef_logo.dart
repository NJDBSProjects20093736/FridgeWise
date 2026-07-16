import 'package:flutter/material.dart';

/// Official ThriftyChef lockup — one stacked unit: hat → wordmark → tagline.
class ThriftyChefLogo extends StatelessWidget {
  final double height;
  final bool showTagline;

  const ThriftyChefLogo({
    super.key,
    this.height = 96,
    this.showTagline = true,
  });

  /// App bar — same stacked lockup, smaller.
  const ThriftyChefLogo.compact({super.key})
      : height = 58,
        showTagline = false;

  /// Onboarding / splash — full lockup with tagline.
  const ThriftyChefLogo.header({super.key})
      : height = 160,
        showTagline = true;

  static const teal = Color(0xFF2F6B66);
  static const coral = Color(0xFFE8A99A);

  @override
  Widget build(BuildContext context) {
    final hatH = height * (showTagline ? 0.42 : 0.55);
    final wordSize = height * (showTagline ? 0.185 : 0.26);
    // Tight gap so hat + wordmark read as one mark (not separate).
    final gapHat = height * 0.02;
    final gapTag = height * 0.035;
    final tagSize = (wordSize * 0.34).clamp(7.5, 11.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: hatH,
            width: hatH * 1.2,
            child: CustomPaint(painter: _BrandHatPainter(color: coral)),
          ),
          SizedBox(height: gapHat),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Thrifty',
                  style: TextStyle(
                    fontSize: wordSize,
                    fontWeight: FontWeight.w800,
                    color: teal,
                    letterSpacing: -0.9,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: 'Chef',
                  style: TextStyle(
                    fontSize: wordSize,
                    fontWeight: FontWeight.w800,
                    color: coral,
                    letterSpacing: -0.7,
                    height: 1,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (showTagline) ...[
            SizedBox(height: gapTag),
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

class ChefBrandMark extends StatelessWidget {
  final double size;
  const ChefBrandMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.2,
      height: size,
      child: CustomPaint(painter: _BrandHatPainter(color: ThriftyChefLogo.coral)),
    );
  }
}

class ChefHatIcon extends StatelessWidget {
  final double size;
  final Color color;
  const ChefHatIcon({super.key, required this.size, this.color = ThriftyChefLogo.coral});

  @override
  Widget build(BuildContext context) => ChefBrandMark(size: size);
}

/// Coral outline chef hat — ¢ in the right crown puff, 3 pleats in the band.
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

    // Soft rounded crown
    final crown = Path()
      ..moveTo(w * 0.16, h * 0.52)
      ..cubicTo(w * 0.08, h * 0.42, w * 0.10, h * 0.16, w * 0.30, h * 0.12)
      ..cubicTo(w * 0.42, h * 0.03, w * 0.52, h * 0.03, w * 0.64, h * 0.10)
      ..cubicTo(w * 0.82, h * 0.08, w * 0.92, h * 0.22, w * 0.88, h * 0.40)
      ..cubicTo(w * 0.90, h * 0.48, w * 0.82, h * 0.52, w * 0.78, h * 0.52)
      ..close();
    canvas.drawPath(crown, stroke);

    // Band
    final bandTop = h * 0.52;
    final bandBottom = h * 0.78;
    final band = RRect.fromLTRBR(
      w * 0.14,
      bandTop,
      w * 0.86,
      bandBottom,
      Radius.circular(h * 0.07),
    );
    canvas.drawRRect(band, stroke);

    // Three short vertical pleats in the left of the band
    final pleat = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (sw * 0.75).clamp(1.3, 2.2)
      ..strokeCap = StrokeCap.round;
    for (final x in [0.30, 0.38, 0.46]) {
      canvas.drawLine(
        Offset(w * x, bandTop + h * 0.06),
        Offset(w * x, bandBottom - h * 0.06),
        pleat,
      );
    }

    // Cent symbol in the right puff of the crown (brand sheet placement)
    final cx = w * 0.70;
    final cy = h * 0.28;
    final r = h * 0.095;
    final cent = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (sw * 0.85).clamp(1.5, 2.5)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.55,
      5.2,
      false,
      cent,
    );
    canvas.drawLine(
      Offset(cx, cy - r * 1.4),
      Offset(cx, cy + r * 1.4),
      cent,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandHatPainter oldDelegate) => oldDelegate.color != color;
}
