import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaveformWidget extends StatefulWidget {
  final List<double> amplitudes;
  final bool isRecording;
  final double height;

  const WaveformWidget({
    super.key,
    required this.amplitudes,
    required this.isRecording,
    this.height = 72,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _idleController,
        builder: (context, _) {
          return CustomPaint(
            painter: _WaveformPainter(
              amplitudes: widget.amplitudes,
              isRecording: widget.isRecording,
              idleProgress: _idleController.value,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final bool isRecording;
  final double idleProgress;

  static const int barCount = 48;
  static const double barWidth = 3.5;
  static const double barGap = 2.0;

  const _WaveformPainter({
    required this.amplitudes,
    required this.isRecording,
    required this.idleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalBarsWidth = barCount * (barWidth + barGap) - barGap;
    final startX = (size.width - totalBarsWidth) / 2;
    final centerY = size.height / 2;
    final maxHalfHeight = (size.height / 2) - 2;

    for (int i = 0; i < barCount; i++) {
      double amplitude;

      if (isRecording && i < amplitudes.length) {
        amplitude = amplitudes[amplitudes.length - barCount + i < 0
                ? 0
                : amplitudes.length - barCount + i]
            .clamp(0.0, 1.0);
      } else {
        // Gentle rolling sine wave when idle
        final phase =
            (idleProgress * 2 * pi * 1.5) + (i / barCount) * 3 * pi;
        amplitude = 0.07 + 0.055 * sin(phase) + 0.02 * sin(phase * 2.3);
      }

      final halfHeight =
          (amplitude * maxHalfHeight).clamp(2.0, maxHalfHeight);
      final x = startX + i * (barWidth + barGap) + barWidth / 2;

      Color color;
      if (isRecording) {
        // Gradient: purple → cyan as amplitude grows
        final t = ((amplitude - 0.15) / 0.85).clamp(0.0, 1.0);
        color = Color.lerp(
          AppTheme.accent,
          AppTheme.accentSecondary,
          t,
        )!.withValues(alpha: 0.35 + amplitude * 0.65);
      } else {
        color = AppTheme.textSecondary.withValues(alpha: 0.15 + amplitude * 0.25);
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Draw top half
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 2, centerY - halfHeight, barWidth, halfHeight),
          const Radius.circular(2),
        ),
        paint,
      );

      // Draw bottom half (mirrored)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 2, centerY, barWidth, halfHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) {
    return old.idleProgress != idleProgress ||
        old.isRecording != isRecording ||
        old.amplitudes.length != amplitudes.length ||
        (amplitudes.isNotEmpty &&
            old.amplitudes.isNotEmpty &&
            old.amplitudes.last != amplitudes.last);
  }
}
