import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated weather icon driven by CustomPainter.
/// Manages its own AnimationControllers so it can live inside a StatelessWidget.
class WeatherAnimation extends StatefulWidget {
  final String iconCode;
  final double size;

  const WeatherAnimation({
    super.key,
    required this.iconCode,
    this.size = 72,
  });

  @override
  State<WeatherAnimation> createState() => _WeatherAnimationState();
}

class _WeatherAnimationState extends State<WeatherAnimation>
    with TickerProviderStateMixin {
  // rotate  → 0..1 looping  (sun spin, cloud drift phase)
  // pulse   → 0..1 reversing (glow breathe, opacity waves)
  // fall    → 0..1 looping  (rain / snow fall progress)
  late AnimationController _rotate;
  late AnimationController _pulse;
  late AnimationController _fall;

  @override
  void initState() {
    super.initState();
    _rotate = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _fall = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _rotate.dispose();
    _pulse.dispose();
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotate, _pulse, _fall]),
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _WeatherPainter(
          iconCode: widget.iconCode,
          rotate: _rotate.value,
          pulse: _pulse.value,
          fall: _fall.value,
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final String iconCode;
  final double rotate; // 0..1
  final double pulse;  // 0..1 reverse
  final double fall;   // 0..1

  const _WeatherPainter({
    required this.iconCode,
    required this.rotate,
    required this.pulse,
    required this.fall,
  });

  @override
  bool shouldRepaint(_WeatherPainter o) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final code = iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';
    switch (code) {
      case '01':
        _sun(canvas, size);
      case '02':
        _partlyCloudy(canvas, size);
      case '03':
      case '04':
        _cloud(canvas, size);
      case '09':
      case '10':
        _rain(canvas, size);
      case '11':
        _thunder(canvas, size);
      case '13':
        _snow(canvas, size);
      case '50':
        _mist(canvas, size);
      default:
        _sun(canvas, size);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _cloudShape(Canvas c, Offset center, double w, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final h = w * 0.56;
    c.drawCircle(center, h * 0.43, p);
    c.drawCircle(Offset(center.dx - w * 0.25, center.dy + h * 0.12), h * 0.30, p);
    c.drawCircle(Offset(center.dx + w * 0.25, center.dy + h * 0.12), h * 0.28, p);
    c.drawCircle(Offset(center.dx - w * 0.10, center.dy + h * 0.22), h * 0.30, p);
    c.drawCircle(Offset(center.dx + w * 0.13, center.dy + h * 0.22), h * 0.27, p);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - w * 0.39,
          center.dy + h * 0.10,
          w * 0.78,
          h * 0.38,
        ),
        Radius.circular(h * 0.16),
      ),
      p,
    );
  }

  // ── ☀️ Sun ─────────────────────────────────────────────────────────────────
  void _sun(Canvas c, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r = s.width * 0.22;
    final rot = rotate * math.pi * 2;

    // Outer glow
    c.drawCircle(
      Offset(cx, cy),
      r * 2.6,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFD740).withOpacity(0.35 + pulse * 0.18),
          const Color(0xFFFFD740).withOpacity(0.0),
        ]).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: r * 2.6),
        ),
    );

    // Rays
    final ray = Paint()
      ..color = const Color(0xFFFFB300)
      ..strokeWidth = s.width * 0.06
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = rot + i * math.pi / 4;
      final cos = math.cos(a);
      final sin = math.sin(a);
      c.drawLine(
        Offset(cx + cos * r * 1.40, cy + sin * r * 1.40),
        Offset(cx + cos * r * 1.88, cy + sin * r * 1.88),
        ray,
      );
    }

    // Disk
    c.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF176), Color(0xFFFFB300)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
  }

  // ── ⛅ Partly Cloudy ───────────────────────────────────────────────────────
  void _partlyCloudy(Canvas c, Size s) {
    final sx = s.width * 0.64;
    final sy = s.height * 0.33;
    final sr = s.width * 0.17;
    final rot = rotate * math.pi * 2;

    // Mini sun rays
    final ray = Paint()
      ..color = const Color(0xFFFFB300).withOpacity(0.85)
      ..strokeWidth = s.width * 0.042
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = rot + i * math.pi / 4;
      c.drawLine(
        Offset(sx + math.cos(a) * sr * 1.28, sy + math.sin(a) * sr * 1.28),
        Offset(sx + math.cos(a) * sr * 1.72, sy + math.sin(a) * sr * 1.72),
        ray,
      );
    }

    // Mini sun disk
    c.drawCircle(
      Offset(sx, sy),
      sr,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF59D), Color(0xFFFFCA28)],
        ).createShader(Rect.fromCircle(center: Offset(sx, sy), radius: sr)),
    );

    // Foreground cloud (drifts slightly)
    final drift = math.sin(rotate * math.pi * 2) * s.width * 0.022;
    _cloudShape(
      c,
      Offset(s.width * 0.40 + drift, s.height * 0.61),
      s.width * 0.65,
      Colors.white,
    );
  }

  // ── ☁️ Cloudy ─────────────────────────────────────────────────────────────
  void _cloud(Canvas c, Size s) {
    final d1 = math.sin(rotate * math.pi * 2) * s.width * 0.028;
    _cloudShape(
      c,
      Offset(s.width * 0.40 + d1, s.height * 0.40),
      s.width * 0.50,
      const Color(0xFFCFD8DC),
    );
    final d2 = math.sin(rotate * math.pi * 2 + 1.3) * s.width * 0.020;
    _cloudShape(
      c,
      Offset(s.width / 2 + d2, s.height * 0.56),
      s.width * 0.72,
      const Color(0xFFB0BEC5),
    );
  }

  // ── 🌧️ Rain ────────────────────────────────────────────────────────────────
  void _rain(Canvas c, Size s) {
    _cloudShape(
      c,
      Offset(s.width / 2, s.height * 0.34),
      s.width * 0.74,
      const Color(0xFF90A4AE),
    );

    final drop = Paint()
      ..color = const Color(0xFF5B9BD5)
      ..strokeWidth = s.width * 0.052
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const n = 6;
    for (int i = 0; i < n; i++) {
      final phase = i / n;
      final prog = (fall + phase) % 1.0;
      final x = s.width * (0.13 + i * 0.15);
      final y = s.height * 0.54 + prog * s.height * 0.38;
      if (y < s.height * 0.96) {
        c.drawLine(
          Offset(x, y),
          Offset(x - s.width * 0.018, y + s.height * 0.085),
          drop,
        );
      }
    }
  }

  // ── ⛈️ Thunderstorm ───────────────────────────────────────────────────────
  void _thunder(Canvas c, Size s) {
    _cloudShape(
      c,
      Offset(s.width / 2, s.height * 0.33),
      s.width * 0.74,
      const Color(0xFF546E7A),
    );

    // Light rain
    final drop = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.62)
      ..strokeWidth = s.width * 0.042
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final phase = i / 5;
      final prog = (fall + phase) % 1.0;
      final x = s.width * (0.15 + i * 0.17);
      final y = s.height * 0.54 + prog * s.height * 0.28;
      if (y < s.height * 0.88) {
        c.drawLine(Offset(x, y), Offset(x - s.width * 0.016, y + s.height * 0.072), drop);
      }
    }

    // Lightning bolt (flashes in the last 35% of the fall cycle)
    if (fall > 0.62) {
      final t = (fall - 0.62) / 0.38;
      final boltPaint = Paint()
        ..color = const Color(0xFFFFEE58).withOpacity(t.clamp(0.0, 1.0))
        ..strokeWidth = s.width * 0.072
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Glow behind bolt
      final glowPaint = Paint()
        ..color = const Color(0xFFFFEE58).withOpacity((t * 0.4).clamp(0.0, 1.0))
        ..strokeWidth = s.width * 0.16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final boltPath = Path()
        ..moveTo(s.width * 0.57, s.height * 0.53)
        ..lineTo(s.width * 0.43, s.height * 0.69)
        ..lineTo(s.width * 0.54, s.height * 0.69)
        ..lineTo(s.width * 0.40, s.height * 0.88);

      c.drawPath(boltPath, glowPaint);
      c.drawPath(boltPath, boltPaint);
    }
  }

  // ── ❄️ Snow ────────────────────────────────────────────────────────────────
  void _snow(Canvas c, Size s) {
    _cloudShape(
      c,
      Offset(s.width / 2, s.height * 0.34),
      s.width * 0.74,
      const Color(0xFFB0BEC5),
    );

    final snowPaint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.fill;

    const n = 7;
    for (int i = 0; i < n; i++) {
      final phase = i / n;
      final prog = (fall * 0.65 + phase) % 1.0;
      final wobble =
          math.sin(prog * math.pi * 2.8 + i * 1.4) * s.width * 0.036;
      final x = s.width * (0.12 + i * 0.13) + wobble;
      final y = s.height * 0.55 + prog * s.height * 0.40;
      if (y < s.height * 0.97) {
        final r = s.width * (0.032 + 0.016 * math.sin(phase * math.pi));
        c.drawCircle(Offset(x, y), r, snowPaint);
      }
    }
  }

  // ── 🌫️ Mist ───────────────────────────────────────────────────────────────
  void _mist(Canvas c, Size s) {
    final paint = Paint()
      ..strokeWidth = s.height * 0.062
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const lines = 5;
    for (int i = 0; i < lines; i++) {
      final y = s.height * (0.20 + i * 0.16);
      final dx = math.sin(rotate * math.pi * 2 + i * 0.95) * s.width * 0.048;
      final opacity = 0.18 + 0.38 * math.sin(pulse * math.pi + i * 0.72).abs();
      paint.color = const Color(0xFF78909C).withOpacity(opacity);

      final x0 = s.width * 0.08 + dx;
      final x1 = s.width * 0.92 + dx;
      final amp = s.height * 0.038;
      final wave = rotate * math.pi * 3.5 + i * 0.9;

      final path = Path()
        ..moveTo(x0, y)
        ..cubicTo(
          x0 + s.width * 0.22,
          y - amp * math.sin(wave),
          x0 + s.width * 0.58,
          y + amp * math.sin(wave + 1.6),
          x1,
          y,
        );
      c.drawPath(path, paint);
    }
  }
}
