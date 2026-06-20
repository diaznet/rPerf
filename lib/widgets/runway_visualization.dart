import 'package:flutter/material.dart';

/// Draws a single runway with one distance overlay (either TO or LDG).
/// [distFromLeft] controls which end the overlay starts from:
///   true  = distance grows from left  (takeoff from LE end)
///   false = distance grows from right (landing towards LE end, i.e. from HE side)
class RunwayVisualization extends StatelessWidget {
  final String leIdent;
  final String heIdent;
  final double runwayLengthM;
  final double availableM;    // TORA, TODA, or LDA
  final String availableLabel; // e.g. "TORA", "TODA", "LDA"
  final double? distanceM;    // computed distance (with margin)
  final String operationLabel; // e.g. "Takeoff" or "Landing"
  final bool distFromLeft;    // true = overlay from left end

  const RunwayVisualization({
    super.key,
    required this.leIdent,
    required this.heIdent,
    required this.runwayLengthM,
    required this.availableM,
    required this.availableLabel,
    required this.operationLabel,
    required this.distFromLeft,
    this.distanceM,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100,
          width: double.infinity,
          child: CustomPaint(
            painter: _RunwayPainter(
              leIdent: leIdent,
              heIdent: heIdent,
              runwayLengthM: runwayLengthM,
              availableM: availableM,
              distanceM: distanceM,
              distFromLeft: distFromLeft,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _legend(),
      ],
    );
  }

  Widget _legend() {
    final items = <Widget>[];
    if (distanceM != null && !distanceM!.isNaN) {
      final ok = distanceM! <= availableM;
      items.add(_legendItem(
        ok ? Colors.green : Colors.red,
        '$operationLabel: ${distanceM!.toStringAsFixed(0)} m',
      ));
    }
    items.add(_legendItem(Colors.white, '$availableLabel: ${availableM.toStringAsFixed(0)} m'));
    return Wrap(spacing: 16, runSpacing: 4, children: items);
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, border: Border.all(color: Colors.grey.shade400, width: 0.5))),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _RunwayPainter extends CustomPainter {
  final String leIdent;
  final String heIdent;
  final double runwayLengthM;
  final double availableM;
  final double? distanceM;
  final bool distFromLeft;

  _RunwayPainter({
    required this.leIdent,
    required this.heIdent,
    required this.runwayLengthM,
    required this.availableM,
    this.distanceM,
    required this.distFromLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rwyMarginH = 16.0;
    const rwyTop = 16.0;
    final rwyHeight = size.height - 30;
    const rwyLeft = rwyMarginH;
    final rwyWidth = size.width - rwyMarginH * 2;

    // Runway background
    final rwyPaint = Paint()..color = const Color(0xFF2A2A2A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rwyLeft, rwyTop, rwyWidth, rwyHeight), const Radius.circular(4)),
      rwyPaint,
    );

    // Center line dashes
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    final centerY = rwyTop + rwyHeight / 2;
    for (double x = rwyLeft + 50; x < rwyLeft + rwyWidth - 50; x += 20) {
      canvas.drawLine(Offset(x, centerY), Offset(x + 12, centerY), dashPaint);
    }

    // Threshold markings
    final threshPaint = Paint()..color = Colors.white..strokeWidth = 2;
    for (double dy = rwyTop + 6; dy < rwyTop + rwyHeight - 6; dy += 7) {
      canvas.drawLine(Offset(rwyLeft + 6, dy), Offset(rwyLeft + 6, dy + 3), threshPaint);
      canvas.drawLine(Offset(rwyLeft + rwyWidth - 6, dy), Offset(rwyLeft + rwyWidth - 6, dy + 3), threshPaint);
    }

    // Scale: fit the max of physical length and available distance
    final maxRef = runwayLengthM > availableM ? runwayLengthM : availableM;
    if (maxRef <= 0) return;
    final scale = rwyWidth / maxRef;

    // Available distance marker (white vertical line)
    final availPx = (availableM * scale).clamp(0.0, rwyWidth);
    final markerPaint = Paint()..color = Colors.white..strokeWidth = 2;
    if (distFromLeft) {
      canvas.drawLine(Offset(rwyLeft + availPx, rwyTop), Offset(rwyLeft + availPx, rwyTop + rwyHeight), markerPaint);
    } else {
      canvas.drawLine(Offset(rwyLeft + rwyWidth - availPx, rwyTop), Offset(rwyLeft + rwyWidth - availPx, rwyTop + rwyHeight), markerPaint);
    }

    // Distance overlay
    if (distanceM != null && !distanceM!.isNaN) {
      final distPx = (distanceM! * scale).clamp(0.0, rwyWidth);
      final ok = distanceM! <= availableM;
      final overlayPaint = Paint()..color = (ok ? Colors.green : Colors.red).withValues(alpha: 0.5);

      if (distFromLeft) {
        canvas.drawRect(Rect.fromLTWH(rwyLeft, rwyTop, distPx, rwyHeight), overlayPaint);
      } else {
        final startX = rwyLeft + rwyWidth - distPx;
        canvas.drawRect(Rect.fromLTWH(startX, rwyTop, distPx, rwyHeight), overlayPaint);
      }

      // Red overflow bar at the limit if exceeded
      if (!ok) {
        final overPaint = Paint()..color = Colors.red..strokeWidth = 3;
        if (distFromLeft) {
          canvas.drawLine(Offset(rwyLeft + availPx, rwyTop), Offset(rwyLeft + availPx, rwyTop + rwyHeight), overPaint);
        } else {
          final limitX = rwyLeft + rwyWidth - availPx;
          canvas.drawLine(Offset(limitX, rwyTop), Offset(limitX, rwyTop + rwyHeight), overPaint);
        }
      }
    }

    // Direction arrow on centerline
    _drawArrow(canvas, rwyLeft, rwyWidth, centerY, distFromLeft);

    // Runway numbers on surface
    _drawRunwayNumber(canvas, leIdent, rwyLeft + 26, rwyTop + rwyHeight / 2, true);
    _drawRunwayNumber(canvas, heIdent, rwyLeft + rwyWidth - 26, rwyTop + rwyHeight / 2, false);
  }

  void _drawArrow(Canvas canvas, double rwyLeft, double rwyWidth, double cy, bool leftToRight) {
    final cx = rwyLeft + rwyWidth / 2;
    const len = 18.0;
    const headLen = 7.0;
    const headW = 5.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dir = leftToRight ? 1.0 : -1.0;
    final tip = Offset(cx + dir * len / 2, cy);
    final tail = Offset(cx - dir * len / 2, cy);
    canvas.drawLine(tail, tip, paint);
    canvas.drawLine(tip, Offset(tip.dx - dir * headLen, cy - headW), paint);
    canvas.drawLine(tip, Offset(tip.dx - dir * headLen, cy + headW), paint);
  }

  void _drawRunwayNumber(Canvas canvas, String text, double cx, double cy, bool isLeEnd) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(isLeEnd ? 1.5708 : -1.5708);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RunwayPainter old) =>
      old.leIdent != leIdent || old.heIdent != heIdent ||
      old.runwayLengthM != runwayLengthM || old.availableM != availableM ||
      old.distanceM != distanceM || old.distFromLeft != distFromLeft;
}
