import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// One colored slice of the gauge ring.
class GaugeSegment {
  final Color color;
  final double value;
  const GaugeSegment(this.color, this.value);
}

/// The diagnostic-instrument disk gauge: a tick scale, a track, and one arc
/// per category. Reused on Idle, Scanning and Done for visual continuity
/// (spec §"The gauge instrument"). Geometry is authored in a 320-unit space
/// (cx/cy 160, r 130, stroke 22) and scaled to [size].
class DiskGauge extends StatelessWidget {
  final double size;
  final List<GaugeSegment> segments;
  final double total;

  /// 0→1 fill animation for the segments.
  final double progress;

  /// Optional center overlay (kicker / hero number / sub line).
  final Widget? center;

  /// Optional single spinner arc (Scanning screen): fraction of the ring and a
  /// rotation in radians. When [spinnerFraction] is null no arc is drawn.
  final double? spinnerFraction;
  final double spinnerRotation;

  const DiskGauge({
    super.key,
    required this.size,
    required this.segments,
    required this.total,
    this.progress = 1,
    this.center,
    this.spinnerFraction,
    this.spinnerRotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(
              segments: segments,
              total: total <= 0 ? 1 : total,
              progress: progress,
              spinnerFraction: spinnerFraction,
              spinnerRotation: spinnerRotation,
            ),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final List<GaugeSegment> segments;
  final double total;
  final double progress;
  final double? spinnerFraction;
  final double spinnerRotation;

  _GaugePainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.spinnerFraction,
    required this.spinnerRotation,
  });

  static const _cx = 160.0;
  static const _r = 130.0;
  static const _stroke = 22.0;
  static const _topStart = -math.pi / 2; // 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320.0);
    final center = const Offset(_cx, _cx);
    final rect = Rect.fromCircle(center: center, radius: _r);

    _paintTicks(canvas, center);

    // Track.
    canvas.drawCircle(
      center,
      _r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.gaugeTrack,
    );

    // Category segments.
    var cumulative = 0.0;
    for (final seg in segments) {
      final fraction = seg.value / total;
      final sweep = fraction * 2 * math.pi * progress;
      if (sweep > 0.0001) {
        canvas.drawArc(
          rect,
          _topStart + (cumulative / total) * 2 * math.pi,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke
            ..color = seg.color,
        );
      }
      cumulative += seg.value;
    }

    // Scanning spinner arc (round cap).
    final sf = spinnerFraction;
    if (sf != null) {
      canvas.drawArc(
        rect,
        _topStart + spinnerRotation,
        sf * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = AppColors.accent,
      );
    }

    canvas.restore();
  }

  void _paintTicks(Canvas canvas, Offset center) {
    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      final theta = i * 6 * math.pi / 180;
      final dir = Offset(math.sin(theta), -math.cos(theta));
      // radius = 160 - y (authored as vertical lines from the top).
      final rOut = major ? 160 - 9 : 160 - 13;
      final rIn = major ? 160 - 22 : 160 - 19;
      canvas.drawLine(
        center + dir * rOut.toDouble(),
        center + dir * rIn.toDouble(),
        Paint()
          ..strokeWidth = major ? 1.6 : 1.0
          ..color = (major ? AppColors.faintest : AppColors.borderControl)
              .withValues(alpha: major ? 0.55 : 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress ||
      old.spinnerRotation != spinnerRotation ||
      old.spinnerFraction != spinnerFraction ||
      old.segments != segments;
}
