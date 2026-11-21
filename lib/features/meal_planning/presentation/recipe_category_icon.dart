import 'package:material_ui/material_ui.dart';

/// A shared outline style keeps the diet categories visually distinct without
/// introducing a second font or external image assets.
class RecipeCategoryIcon extends StatelessWidget {
  const RecipeCategoryIcon(
    this.category, {
    super.key,
    required this.color,
    this.size = 26,
    this.fallback = Icons.restaurant_outlined,
  });
  final String category;
  final Color color;
  final double size;
  final IconData fallback;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ['all', 'meat', 'fish', 'vegetarian', 'vegan'].contains(category)
        ? CustomPaint(painter: _CategoryPainter(category, color))
        : Icon(fallback, size: size, color: color),
  );
}

class _CategoryPainter extends CustomPainter {
  const _CategoryPainter(this.category, this.color);
  final String category;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (category) {
      case 'all':
        for (final x in [5.0, 18.0]) {
          for (final y in [5.0, 18.0]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, 9, 9),
                const Radius.circular(2.5),
              ),
              stroke,
            );
          }
        }
      case 'meat':
        final steak = Path()
          ..moveTo(6, 12)
          ..cubicTo(9, 4, 18, 3, 24, 8)
          ..cubicTo(30, 12, 29, 17, 24, 20)
          ..cubicTo(21, 22, 21, 27, 15, 28)
          ..cubicTo(7, 29, 2, 21, 6, 12)
          ..close();
        canvas.drawPath(steak, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(9, 14)
            ..cubicTo(12, 8, 19, 7, 23, 12)
            ..cubicTo(26, 16, 20, 17, 18, 21)
            ..cubicTo(14, 27, 6, 22, 9, 14),
          stroke,
        );
        canvas.drawOval(const Rect.fromLTWH(15, 12, 6, 5), stroke);
      case 'fish':
        canvas.drawPath(
          Path()
            ..moveTo(4, 16)
            ..cubicTo(10, 6, 21, 6, 25, 16)
            ..cubicTo(21, 26, 10, 26, 4, 16)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(24, 15)
            ..lineTo(30, 10)
            ..lineTo(30, 22)
            ..lineTo(24, 17),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(11, 9)
            ..quadraticBezierTo(16, 16, 11, 23),
          stroke,
        );
        canvas.drawCircle(const Offset(8.5, 15), 1.2, Paint()..color = color);
        canvas.drawPath(
          Path()
            ..moveTo(15, 8)
            ..lineTo(20, 4)
            ..lineTo(22, 11),
          stroke,
        );
      case 'vegetarian':
        canvas.drawPath(
          Path()
            ..moveTo(7, 25)
            ..cubicTo(2, 10, 14, 5, 27, 5)
            ..cubicTo(27, 19, 22, 29, 7, 25)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(5, 28)
            ..quadraticBezierTo(12, 17, 23, 10)
            ..moveTo(11, 20)
            ..lineTo(11, 14)
            ..moveTo(15, 16)
            ..lineTo(22, 17),
          stroke,
        );
      case 'vegan':
        canvas.drawPath(
          Path()
            ..moveTo(16, 28)
            ..lineTo(16, 17),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 22)
            ..cubicTo(6, 24, 3, 17, 4, 12)
            ..cubicTo(12, 11, 17, 15, 16, 22)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 17)
            ..cubicTo(15, 8, 20, 4, 28, 5)
            ..cubicTo(29, 13, 24, 19, 16, 17)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 22)
            ..lineTo(8, 16)
            ..moveTo(16, 17)
            ..lineTo(24, 9),
          stroke,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CategoryPainter oldDelegate) =>
      category != oldDelegate.category || color != oldDelegate.color;
}
