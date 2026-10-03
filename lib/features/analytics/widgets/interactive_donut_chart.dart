import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/theme/app_colors.dart';
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

  static const double _pedestalSize = 264.0;
  static const double _ringSize = 228.0;
  static const double _baseStroke = 22.0;
  static const double _activeStroke = 30.0;

  void _handleTapUp(TapUpDetails details) {
    if (slices.isEmpty || totalSpent <= 0) return;

    const Offset center = Offset(_pedestalSize / 2, _pedestalSize / 2);
    final Offset touchOffset = details.localPosition - center;
    final double distance = touchOffset.distance;

    const double outerRadius = (_ringSize / 2) + 12;
    const double innerRadius = (_ringSize / 2) - _activeStroke - 16;

    if (distance < innerRadius || distance > outerRadius) {
      onSliceSelected(null);
      return;
    }

    double angle = math.atan2(touchOffset.dy, touchOffset.dx) + (math.pi / 2);
    if (angle < 0) {
      angle += 2 * math.pi;
    }

    double startAngle = 0.0;
    for (final AllocationSlice slice in slices) {
      final double sweep = (slice.amount / totalSpent) * 2 * math.pi;
      if (angle >= startAngle && angle <= startAngle + sweep) {
        onSliceSelected(selectedSliceId == slice.id ? null : slice.id);
        return;
      }
      startAngle += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

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
    final String topLabel = activeSlice != null
        ? activeSlice.title.toUpperCase()
        : l10n.analyticsTotalSpent;
    final double displayAmount = activeSlice?.amount ?? totalSpent;

    String pillText;
    if (activeSlice != null && totalSpent > 0) {
      final String pct =
          ((activeSlice.amount / totalSpent) * 100).toStringAsFixed(1);
      pillText = pct + '% • ' + activeSlice.totalQuantity.toString() + 'x';
    } else if (hasData) {
      pillText = slices.length == 1
          ? l10n.analyticsSingleSource
          : l10n.analyticsMultipleSources(slices.length.toString());
    } else {
      pillText = l10n.analyticsNoActivity;
    }

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleTapUp,
        child: Container(
          width: _pedestalSize,
          height: _pedestalSize,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: AppColors.softShadow,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: < Widget >[
              SizedBox(
                width: _ringSize,
                height: _ringSize,
                child: TweenAnimationBuilder< double >(
                  tween: Tween< double >(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double progress, _) {
                    return CustomPaint(
                      painter: _RingAllocationPainter(
                        slices: slices,
                        total: totalSpent,
                        selectedSliceId: selectedSliceId,
                        progress: progress,
                        baseStroke: _baseStroke,
                        activeStroke: _activeStroke,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey< String >(activeSlice?.id ?? 'summary_center'),
                    mainAxisSize: MainAxisSize.min,
                    children: < Widget >[
                      Text(
                        topLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppColors.greyText,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: AppColors.greyText,
                              ),
                            ),
                            Text(
                              IdrFormatter.numberOnly(displayAmount),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: activeSlice != null
                              ? activeSlice.color.withValues(alpha: 0.12)
                              : ForestTokens.canvasMint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pillText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: activeSlice?.color ?? AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingAllocationPainter extends CustomPainter {
  final List< AllocationSlice > slices;
  final double total;
  final String? selectedSliceId;
  final double progress;
  final double baseStroke;
  final double activeStroke;

  _RingAllocationPainter({
    required this.slices,
    required this.total,
    required this.selectedSliceId,
    required this.progress,
    required this.baseStroke,
    required this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - (activeStroke / 2);

    final Paint trackPaint = Paint()
      ..color = ForestTokens.canvasMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (slices.isEmpty || total <= 0) return;

    final double gap = slices.length > 1 ? 0.038 : 0.0;
    double startAngle = -math.pi / 2;
    final double maxSweep = 2 * math.pi * progress;

    for (final AllocationSlice slice in slices) {
      final double rawSweep = (slice.amount / total) * maxSweep;
      final double effectiveSweep = math.max(0.0, rawSweep - gap);
      final bool isSelected = selectedSliceId == slice.id;
      final bool isDimmed = selectedSliceId != null && !isSelected;

      final Paint segmentPaint = Paint()
        ..color =
            isDimmed ? slice.color.withValues(alpha: 0.22) : slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? activeStroke : baseStroke
        ..strokeCap = slices.length == 1 ? StrokeCap.round : StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: isSelected ? radius + 2.0 : radius,
        ),
        startAngle + (gap / 2),
        effectiveSweep,
        false,
        segmentPaint,
      );

      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingAllocationPainter oldDelegate) {
    return oldDelegate.selectedSliceId != selectedSliceId ||
        oldDelegate.progress != progress ||
        oldDelegate.total != total ||
        oldDelegate.slices != slices;
  }
}