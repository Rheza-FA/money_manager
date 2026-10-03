import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/analytics_models.dart';

class InteractiveDonutChart extends StatelessWidget {
  final List< AllocationSlice > slices;
  final double totalSpent;
  final String? selectedSliceId;
  final ValueChanged< String? > onSliceSelected;

  const InteractiveDonutChart({
    super.key,
    required this.slices,
    required this.totalSpent,
    required this.selectedSliceId,
    required this.onSliceSelected,
  });

  static const double _chartSize = 224.0;
  static const double _baseStrokeWidth = 26.0;
  static const double _selectedStrokeWidth = 34.0;

  void _handleTapUp(TapUpDetails details) {
    if (slices.isEmpty || totalSpent <= 0) return;

    const Offset center = Offset(_chartSize / 2, _chartSize / 2);
    final Offset touchOffset = details.localPosition - center;
    final double distance = touchOffset.distance;

    const double outerRadius = (_chartSize / 2) - (_selectedStrokeWidth / 2) + 14;
    const double innerRadius = outerRadius - _selectedStrokeWidth - 18;

    if (distance < innerRadius || distance > outerRadius) {
      onSliceSelected(null);
      return;
    }

    double touchAngle =
        math.atan2(touchOffset.dy, touchOffset.dx) + (math.pi / 2);
    if (touchAngle < 0) {
      touchAngle += 2 * math.pi;
    }

    double currentStartAngle = 0.0;
    for (final AllocationSlice slice in slices) {
      final double sweepAngle = (slice.amount / totalSpent) * 2 * math.pi;
      if (touchAngle >= currentStartAngle &&
          touchAngle <= currentStartAngle + sweepAngle) {
        if (selectedSliceId == slice.id) {
          onSliceSelected(null);
        } else {
          onSliceSelected(slice.id);
        }
        return;
      }
      currentStartAngle += sweepAngle;
    }
  }

  @override
  Widget build(BuildContext context) {
    AllocationSlice? activeSlice;
    if (selectedSliceId != null) {
      for (final AllocationSlice s in slices) {
        if (s.id == selectedSliceId) {
          activeSlice = s;
          break;
        }
      }
    }

    final bool hasData = slices.isNotEmpty && totalSpent > 0;
    final String centerLabel =
        activeSlice?.title ?? (hasData ? 'Total Porsi' : 'Belum Ada Data');
    final double centerAmount = activeSlice?.amount ?? totalSpent;
    final String centerBadgeText = activeSlice != null && totalSpent > 0
        ? (((activeSlice.amount / totalSpent) * 100).toStringAsFixed(1) +
            '% • ' +
            activeSlice.totalQuantity.toString() +
            'x')
        : (hasData ? (slices.length.toString() + ' Pos Pengeluaran') : 'Rp 0');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp,
      child: SizedBox(
        width: _chartSize,
        height: _chartSize,
        child: TweenAnimationBuilder< double >(
          tween: Tween< double >(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double progress, Widget? child) {
            return CustomPaint(
              painter: _ForestDonutPainter(
                slices: slices,
                total: totalSpent,
                selectedSliceId: selectedSliceId,
                animationProgress: progress,
                baseStrokeWidth: _baseStrokeWidth,
                selectedStrokeWidth: _selectedStrokeWidth,
              ),
              child: child,
            );
          },
          child: Center(
            child: Container(
              width: _chartSize - (_selectedStrokeWidth * 2) - 22,
              height: _chartSize - (_selectedStrokeWidth * 2) - 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: < BoxShadow >[
                  BoxShadow(
                    color: ForestAnalyticsPalette.deepForest
                        .withValues(alpha: 0.05),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey< String >(activeSlice?.id ?? 'all_total'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: < Widget >[
                    Text(
                      centerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ForestAnalyticsPalette.bodyGreyText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: < Widget >[
                          const Text(
                            'Rp ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ForestAnalyticsPalette.bodyGreyText,
                            ),
                          ),
                          Text(
                            IdrFormatter.numberOnly(centerAmount),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: ForestAnalyticsPalette.deepForest,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: activeSlice != null
                            ? activeSlice.color.withValues(alpha: 0.14)
                            : ForestAnalyticsPalette.iconBoxMint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        centerBadgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: activeSlice?.color ??
                              ForestAnalyticsPalette.deepForest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForestDonutPainter extends CustomPainter {
  final List< AllocationSlice > slices;
  final double total;
  final String? selectedSliceId;
  final double animationProgress;
  final double baseStrokeWidth;
  final double selectedStrokeWidth;

  _ForestDonutPainter({
    required this.slices,
    required this.total,
    required this.selectedSliceId,
    required this.animationProgress,
    required this.baseStrokeWidth,
    required this.selectedStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - (selectedStrokeWidth / 2) - 4;

    final Paint trackPaint = Paint()
      ..color = ForestAnalyticsPalette.scaffoldMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (slices.isEmpty || total <= 0) return;

    final double gapRadians = slices.length > 1 ? 0.04 : 0.0;
    double startAngle = -math.pi / 2;
    final double maxSweep = 2 * math.pi * animationProgress;

    for (final AllocationSlice slice in slices) {
      final double rawSweep = (slice.amount / total) * maxSweep;
      final double effectiveSweep = math.max(0.0, rawSweep - gapRadians);
      final bool isSelected = selectedSliceId == slice.id;
      final bool isDimmed = selectedSliceId != null && !isSelected;

      final Paint paint = Paint()
        ..color =
            isDimmed ? slice.color.withValues(alpha: 0.25) : slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? selectedStrokeWidth : baseStrokeWidth
        ..strokeCap = slices.length == 1 ? StrokeCap.round : StrokeCap.butt;

      final double activeRadius = isSelected ? radius + 3.0 : radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: activeRadius),
        startAngle + (gapRadians / 2),
        effectiveSweep,
        false,
        paint,
      );

      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ForestDonutPainter oldDelegate) {
    return oldDelegate.selectedSliceId != selectedSliceId ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.total != total ||
        oldDelegate.slices != slices;
  }
}