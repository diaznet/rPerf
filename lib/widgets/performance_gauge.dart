import 'dart:math';
import 'package:flutter/material.dart';

/// Circular gauge showing runway usage as a percentage.
/// Green < 60%, yellow 60-80%, red > 80%.
class PerformanceGauge extends StatelessWidget {
  final double percentage;
  final String label;
  final double? distanceM;
  final double? availableM;

  const PerformanceGauge({
    super.key,
    required this.percentage,
    required this.label,
    this.distanceM,
    this.availableM,
  });

  Color _gaugeColor() {
    if (percentage >= 80) return Colors.red;
    if (percentage >= 60) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percentage.clamp(0, 120).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _GaugePainter(
              percentage: clamped,
              color: _gaugeColor(),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _gaugeColor(),
                ),
              ),
            ),
          ),
        ),
        if (distanceM != null && availableM != null) ...[
          const SizedBox(height: 4),
          Text(
            '${distanceM!.toStringAsFixed(0)} / ${availableM!.toStringAsFixed(0)} m',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;

  _GaugePainter({required this.percentage, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 10.0;
    const startAngle = -pi / 2; // 12 o'clock
    const fullSweep = 2 * pi;

    // Background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc
    final sweep = fullSweep * (percentage / 100.0).clamp(0, 1);
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.percentage != percentage || old.color != color;
}
