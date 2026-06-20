import 'dart:math';
import 'package:flutter/material.dart';

/// Compact wind arrow showing wind direction relative to a runway heading.
/// The arrow points in the direction the wind is coming FROM.
/// The runway is shown as a fixed vertical line (top = runway heading).
class WindArrow extends StatelessWidget {
  final double windDirDeg; // direction wind comes FROM
  final double runwayHdgDeg; // runway heading
  final double windSpeedKts;
  final double headwindKts;
  final double crosswindKts;
  final double size;

  const WindArrow({
    super.key,
    required this.windDirDeg,
    required this.runwayHdgDeg,
    required this.windSpeedKts,
    required this.headwindKts,
    required this.crosswindKts,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _WindArrowPainter(
              windDirDeg: windDirDeg,
              runwayHdgDeg: runwayHdgDeg,
              windSpeedKts: windSpeedKts,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${windSpeedKts.toStringAsFixed(0)} kt from ${windDirDeg.toStringAsFixed(0)}°',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'HW ${headwindKts.toStringAsFixed(0)} / XW ${crosswindKts.abs().toStringAsFixed(0)} kt',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _WindArrowPainter extends CustomPainter {
  final double windDirDeg;
  final double runwayHdgDeg;
  final double windSpeedKts;

  _WindArrowPainter({
    required this.windDirDeg,
    required this.runwayHdgDeg,
    required this.windSpeedKts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Draw compass circle
    final circlePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw runway line (vertical = runway heading direction)
    final rwyPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final rwyLen = radius * 0.7;
    canvas.drawLine(
      center + Offset(0, -rwyLen),
      center + Offset(0, rwyLen),
      rwyPaint,
    );

    // Small runway direction indicator at top
    final rwyLabelPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + Offset(-6, -rwyLen),
      center + Offset(6, -rwyLen),
      rwyLabelPaint,
    );

    // Wind arrow: angle relative to runway
    // 0° relative = pure headwind (from top), 180° = pure tailwind (from bottom)
    final relAngleDeg = windDirDeg - runwayHdgDeg;
    final relAngleRad = relAngleDeg * pi / 180;

    // Arrow points FROM the wind direction toward center
    final arrowStart = center + Offset(
      radius * 0.85 * sin(relAngleRad),
      -radius * 0.85 * cos(relAngleRad),
    );
    final arrowEnd = center + Offset(
      radius * 0.2 * sin(relAngleRad),
      -radius * 0.2 * cos(relAngleRad),
    );

    // Arrow color based on headwind vs tailwind
    final isHeadwind = (relAngleDeg % 360 + 360) % 360;
    Color arrowColor;
    if (isHeadwind <= 90 || isHeadwind >= 270) {
      arrowColor = Colors.green.shade700;
    } else {
      arrowColor = Colors.red.shade700;
    }

    final arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(arrowStart, arrowEnd, arrowPaint);

    // Arrowhead
    final headLen = radius * 0.15;
    final headAngle = atan2(arrowEnd.dy - arrowStart.dy, arrowEnd.dx - arrowStart.dx);
    final head1 = arrowEnd - Offset(
      headLen * cos(headAngle - 0.4),
      headLen * sin(headAngle - 0.4),
    );
    final head2 = arrowEnd - Offset(
      headLen * cos(headAngle + 0.4),
      headLen * sin(headAngle + 0.4),
    );
    final headPath = Path()
      ..moveTo(arrowEnd.dx, arrowEnd.dy)
      ..lineTo(head1.dx, head1.dy)
      ..lineTo(head2.dx, head2.dy)
      ..close();
    canvas.drawPath(headPath, Paint()..color = arrowColor..style = PaintingStyle.fill);

    // Wind speed label in corner
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${windSpeedKts.toStringAsFixed(0)}kt',
        style: TextStyle(fontSize: 10, color: arrowColor, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 2, 2));
  }

  @override
  bool shouldRepaint(covariant _WindArrowPainter old) =>
      old.windDirDeg != windDirDeg || old.runwayHdgDeg != runwayHdgDeg || old.windSpeedKts != windSpeedKts;
}
