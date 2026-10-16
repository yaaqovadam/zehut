import 'package:flutter/material.dart';


class MagenDavidHouseIcon extends StatelessWidget {
  final double size;
  final Color? houseColor; // Made optional
  final Color? starColor;  // Made optional

  const MagenDavidHouseIcon({
    super.key,
    required this.size,
    this.houseColor,
    this.starColor,
  });

  @override
  Widget build(BuildContext context) {
    // 🎯 If no color is passed, it automatically inherits the active/inactive color from the surrounding Tab/Menu
    final activeThemeColor = IconTheme.of(context).color ?? Colors.grey;

    return CustomPaint(
      size: Size(size, size),
      painter: _MagenDavidHousePainter(
        houseColor: houseColor ?? activeThemeColor,
        starColor: starColor ?? Colors.white,
      ),
    );
  }
}

class _MagenDavidHousePainter extends CustomPainter {
  final Color houseColor;
  final Color starColor;

  _MagenDavidHousePainter({required this.houseColor, required this.starColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Draw the House Background
    final Paint housePaint = Paint()
      ..color = houseColor
      ..style = PaintingStyle.fill;

    final Path housePath = Path();
    housePath.moveTo(w * 0.5, 0);
    // 🎯 Pushed the eaves up slightly and widened the walls
    housePath.lineTo(w, h * 0.40);
    housePath.lineTo(w * 0.90, h * 0.40); // Right wall wider
    housePath.lineTo(w * 0.90, h);
    housePath.lineTo(w * 0.10, h);        // Left wall wider
    housePath.lineTo(w * 0.10, h * 0.40);
    housePath.lineTo(0, h * 0.40);
    housePath.close();

    canvas.drawPath(housePath, housePaint);

    // 2. Draw the Star of David
    final Paint starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035 // 🎯 Thinned out the star lines
      ..strokeJoin = StrokeJoin.round;

    final Path starPath = Path();
    final double cx = w * 0.5;
    final double cy = h * 0.60;
    final double r = w * 0.23; // Slightly expanded radius to fill the wider house
    final double dx = r * 0.866;
    final double dy = r * 0.5;

    starPath.moveTo(cx, cy - r);
    starPath.lineTo(cx + dx, cy + dy);
    starPath.lineTo(cx - dx, cy + dy);
    starPath.close();

    starPath.moveTo(cx, cy + r);
    starPath.lineTo(cx + dx, cy - dy);
    starPath.lineTo(cx - dx, cy - dy);
    starPath.close();

    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//////////////////////////


class MagenDavidShieldIcon extends StatelessWidget {
  final double size;
  final Color? shieldColor;
  final Color? starColor;

  const MagenDavidShieldIcon({
    super.key,
    required this.size,
    this.shieldColor,
    this.starColor,
  });

  @override
  Widget build(BuildContext context) {
    // 🎯 Inherits the active/inactive color from the Tab Menu automatically
    final activeThemeColor = IconTheme.of(context).color ?? Colors.grey;

    return CustomPaint(
      size: Size(size, size),
      painter: _MagenDavidShieldPainter(
        shieldColor: shieldColor ?? activeThemeColor,
        starColor: starColor ?? Colors.white,
      ),
    );
  }
}

class _MagenDavidShieldPainter extends CustomPainter {
  final Color shieldColor;
  final Color starColor;

  _MagenDavidShieldPainter({required this.shieldColor, required this.starColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Draw the Shield Background
    final Paint shieldPaint = Paint()
      ..color = shieldColor
      ..style = PaintingStyle.fill;

    final Path shieldPath = Path();
    // Top left
    shieldPath.moveTo(w * 0.15, h * 0.10);
    // Flat top to top right
    shieldPath.lineTo(w * 0.85, h * 0.10);
    // Straight down the sides
    shieldPath.lineTo(w * 0.85, h * 0.45);
    // Smooth curve down to the bottom point
    shieldPath.quadraticBezierTo(w * 0.85, h * 0.80, w * 0.50, h * 0.95);
    // Smooth curve back up to the left side
    shieldPath.quadraticBezierTo(w * 0.15, h * 0.80, w * 0.15, h * 0.45);
    shieldPath.close();

    canvas.drawPath(shieldPath, shieldPaint);

    // 2. Draw the Star of David
    final Paint starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035 // 🎯 Matches the thin aesthetic of the house star
      ..strokeJoin = StrokeJoin.round;

    final Path starPath = Path();
    final double cx = w * 0.5;
    // Pushed up slightly so it centers perfectly in the bulk of the shield
    final double cy = h * 0.46;
    final double r = w * 0.22;
    final double dx = r * 0.866;
    final double dy = r * 0.5;

    // Upward triangle
    starPath.moveTo(cx, cy - r);
    starPath.lineTo(cx + dx, cy + dy);
    starPath.lineTo(cx - dx, cy + dy);
    starPath.close();

    // Downward triangle
    starPath.moveTo(cx, cy + r);
    starPath.lineTo(cx + dx, cy - dy);
    starPath.lineTo(cx - dx, cy - dy);
    starPath.close();

    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}