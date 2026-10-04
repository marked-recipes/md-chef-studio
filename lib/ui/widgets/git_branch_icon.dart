import 'package:flutter/material.dart';

/// Renders the official Git branch / Source Control icon (matching VS Code and Git).
class GitBranchIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GitBranchIcon({
    super.key,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.grey;
    return CustomPaint(
      size: Size(size, size),
      painter: _GitBranchIconPainter(color: iconColor),
    );
  }
}

class _GitBranchIconPainter extends CustomPainter {
  final Color color;

  _GitBranchIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final nodeRadius = 2.6 * s;

    // 1. Main vertical trunk
    canvas.drawLine(
      Offset(7.5 * s, 6.0 * s),
      Offset(7.5 * s, 18.0 * s),
      strokePaint,
    );

    // 2. Curved branch leading to the right node
    final branchPath = Path();
    branchPath.moveTo(7.5 * s, 13.5 * s);
    branchPath.cubicTo(
      7.5 * s, 9.5 * s,
      12.5 * s, 8.5 * s,
      16.5 * s, 8.5 * s,
    );
    canvas.drawPath(branchPath, strokePaint);

    // 3. Circular nodes (dots)
    canvas.drawCircle(Offset(7.5 * s, 6.0 * s), nodeRadius, fillPaint);
    canvas.drawCircle(Offset(7.5 * s, 18.0 * s), nodeRadius, fillPaint);
    canvas.drawCircle(Offset(16.5 * s, 8.5 * s), nodeRadius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _GitBranchIconPainter oldDelegate) => oldDelegate.color != color;
}

