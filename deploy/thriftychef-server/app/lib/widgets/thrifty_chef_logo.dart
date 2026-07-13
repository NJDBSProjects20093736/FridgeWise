import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small chef-toque icon drawn to sit above the "Chef" wordmark.
class ChefHatIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ChefHatIcon({super.key, required this.size, this.color = const Color(0xFFE8A598)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.1, size),
      painter: _ChefHatPainter(color: color),
    );
  }
}

class _ChefHatPainter extends CustomPainter {
  final Color color;

  _ChefHatPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bandH = h * 0.22;

    // Puffy top
    final top = Path()
      ..moveTo(w * 0.08, bandH + h * 0.02)
      ..quadraticBezierTo(w * 0.02, h * 0.15, w * 0.18, h * 0.04)
      ..quadraticBezierTo(w * 0.5, -h * 0.08, w * 0.82, h * 0.04)
      ..quadraticBezierTo(w * 0.98, h * 0.15, w * 0.92, bandH + h * 0.02)
      ..close();

    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, bandH, w * 0.88, bandH),
      Radius.circular(bandH * 0.35),
    );

    final fill = Paint()..color = color;
    final bandFill = Paint()..color = Color.lerp(color, Colors.white, 0.25)!;
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(top, fill);
    canvas.drawPath(top, stroke);
    canvas.drawRRect(band, bandFill);
    canvas.drawRRect(band, stroke);
  }

  @override
  bool shouldRepaint(covariant _ChefHatPainter oldDelegate) => oldDelegate.color != color;
}

/// Branded ThriftyChef logo — wordmark with chef hat on "Chef".
class ThriftyChefLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showIcon;
  final bool horizontal;
  final bool showHat;

  const ThriftyChefLogo({
    super.key,
    this.iconSize = 36,
    this.fontSize = 22,
    this.showIcon = false,
    this.horizontal = true,
    this.showHat = true,
  });

  const ThriftyChefLogo.compact({super.key})
      : iconSize = 26,
        fontSize = 17,
        showIcon = false,
        horizontal = true,
        showHat = true;

  const ThriftyChefLogo.header({super.key})
      : iconSize = 72,
        fontSize = 28,
        showIcon = false,
        horizontal = false,
        showHat = true;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final scaledFont = narrow ? fontSize * 0.9 : fontSize;
    final scaledIcon = narrow ? iconSize * 0.9 : iconSize;

    final mark = Container(
      width: scaledIcon + 8,
      height: scaledIcon + 8,
      decoration: BoxDecoration(
        gradient: AppTheme.glacierHeroGradient,
        borderRadius: BorderRadius.circular(scaledIcon * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.glacier.withValues(alpha: AppTheme.c.useGlow ? 0.45 : 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.restaurant_menu, color: Colors.white, size: scaledIcon * 0.52),
    );

    final wordmark = _Wordmark(fontSize: scaledFont, showHat: showHat);

    if (!showIcon) {
      return FittedBox(fit: BoxFit.scaleDown, child: wordmark);
    }

    final content = horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(width: scaledFont * 0.4),
              wordmark,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(height: scaledFont * 0.55),
              wordmark,
            ],
          );

    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: content);
  }
}

class _Wordmark extends StatelessWidget {
  final double fontSize;
  final bool showHat;

  const _Wordmark({required this.fontSize, required this.showHat});

  @override
  Widget build(BuildContext context) {
    final hatSize = fontSize * 0.95;
    final chefStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: AppTheme.roseAccent,
      letterSpacing: -0.5,
      height: 1,
    );

    final chefWord = showHat
        ? Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: EdgeInsets.only(top: hatSize * 0.62),
                child: Text('Chef', style: chefStyle),
              ),
              Positioned(
                top: 0,
                child: ChefHatIcon(size: hatSize, color: AppTheme.roseAccent),
              ),
            ],
          )
        : Text('Chef', style: chefStyle);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Thrifty',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        chefWord,
      ],
    );
  }
}
