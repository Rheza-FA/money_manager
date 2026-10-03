import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import '../models/analytics_models.dart';

class ForestPaceHeroCard extends StatefulWidget {
  final AnalyticsSnapshot snapshot;

  const ForestPaceHeroCard({
    super.key,
    required this.snapshot,
  });

  @override
  State< ForestPaceHeroCard > createState() => _ForestPaceHeroCardState();
}

class _ForestPaceHeroCardState extends State< ForestPaceHeroCard > {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _resolveInitialIndex();
  }

  @override
  void didUpdateWidget(covariant ForestPaceHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.paceSeries != widget.snapshot.paceSeries) {
      _selectedIndex = _resolveInitialIndex();
    }
  }

  int _resolveInitialIndex() {
    final List< PaceBarPoint > series = widget.snapshot.paceSeries;
    if (series.isEmpty) return -1;
    for (int i = series.length - 1; i >= 0; i--) {
      if (series[i].isCurrent || series[i].spent > 0) return i;
    }
    return series.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List< PaceBarPoint > series = widget.snapshot.paceSeries;
    final PaceBarPoint? activePoint =
        (_selectedIndex >= 0 && _selectedIndex < series.length)
            ? series[_selectedIndex]
            : null;

    final double headlineAmount =
        activePoint?.spent ?? widget.snapshot.totalSpent;
    final double benchmark =
        activePoint?.safeLimit ?? widget.snapshot.dailyLimit;

    String statusLine;
    if (benchmark > 0) {
      final double diff = benchmark - headlineAmount;
      if (diff >= 0) {
        statusLine = l10n.analyticsUnderSafeLimit(
          IdrFormatter.format(diff),
          IdrFormatter.format(benchmark),
        );
      } else {
        statusLine = l10n.analyticsOverSafeLimit(
          IdrFormatter.format(diff.abs()),
          IdrFormatter.format(benchmark),
        );
      }
    } else {
      statusLine = l10n.analyticsAvgPerDay(
        IdrFormatter.format(widget.snapshot.averageDailySpent),
      );
    }

    final double? delta = widget.snapshot.deltaPercentage;
    String pillLabel;
    IconData pillIcon;
    if (delta != null) {
      final String sign = delta > 0 ? '+' : '';
      pillLabel = l10n.analyticsVsPrev(sign + delta.toStringAsFixed(0));
      pillIcon = delta <= 0
          ? Icons.trending_down_rounded
          : Icons.trending_up_rounded;
    } else {
      pillLabel = widget.snapshot.isBiWeeklyMode
          ? l10n.analyticsBiWeekly
          : l10n.analyticsFullMonth;
      pillIcon = Icons.calendar_today_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ForestTokens.primaryForest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: < BoxShadow >[
          BoxShadow(
            color: ForestTokens.primaryForest.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: < Widget >[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: < Widget >[
              Row(
                children: < Widget >[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: ForestTokens.mintAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      size: 14,
                      color: ForestTokens.primaryForest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    activePoint != null
                        ? l10n.analyticsPacePrefix(
                            activePoint.contextTitle.toUpperCase(),
                          )
                        : l10n.analyticsSpendingPace,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: ForestTokens.mintAccent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: < Widget >[
                    Icon(
                      pillIcon,
                      size: 14,
                      color: ForestTokens.mintAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pillLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: < Widget >[
                const Text(
                  'Rp ',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: ForestTokens.mutedSage,
                  ),
                ),
                Text(
                  IdrFormatter.numberOnly(headlineAmount),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: ForestTokens.mutedSage,
            ),
          ),
          const SizedBox(height: 22),
          if (series.isNotEmpty) _buildInteractiveBars(series, benchmark),
        ],
      ),
    );
  }

  Widget _buildInteractiveBars(List< PaceBarPoint > series, double benchmark) {
    double maxVal = 0.0;
    for (final PaceBarPoint pt in series) {
      maxVal = math.max(maxVal, math.max(pt.spent, pt.safeLimit));
    }
    if (maxVal <= 0) maxVal = 1.0;
    final double ceiling = maxVal * 1.15;

    return SizedBox(
      height: 118,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double labelRowHeight = 24.0;
          final double barZoneHeight = constraints.maxHeight - labelRowHeight;
          final double limitRatio =
              benchmark > 0 ? (benchmark / ceiling).clamp(0.0, 1.0) : 0.0;
          final double limitTop = barZoneHeight * (1.0 - limitRatio);

          return Stack(
            clipBehavior: Clip.none,
            children: < Widget >[
              if (benchmark > 0)
                Positioned(
                  top: limitTop,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 1.5),
                    painter: _LimitDashedLinePainter(
                      color: ForestTokens.mintAccent.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List< Widget >.generate(series.length, (int idx) {
                  final PaceBarPoint pt = series[idx];
                  final bool isSelected = idx == _selectedIndex;
                  final double heightFactor = pt.spent > 0
                      ? (pt.spent / ceiling).clamp(0.1, 1.0)
                      : 0.06;

                  Color barFill;
                  if (pt.spent <= 0) {
                    barFill = Colors.white.withValues(alpha: 0.10);
                  } else if (pt.isOverLimit) {
                    barFill = isSelected
                        ? ForestTokens.coralAlert
                        : ForestTokens.coralAlert.withValues(alpha: 0.55);
                  } else {
                    barFill = isSelected
                        ? Colors.white
                        : ForestTokens.mintAccent.withValues(alpha: 0.55);
                  }

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedIndex = idx),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: < Widget >[
                          SizedBox(
                            height: barZoneHeight,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                width: isSelected ? 24 : 18,
                                height: barZoneHeight * heightFactor,
                                decoration: BoxDecoration(
                                  color: barFill,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: labelRowHeight - 6,
                            child: Text(
                              pt.label,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : ForestTokens.mutedSage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LimitDashedLinePainter extends CustomPainter {
  final Color color;

  _LimitDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5.0;
    const double dashGap = 4.0;
    double x = 0.0;

    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dashWidth, size.width), 0),
        paint,
      );
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _LimitDashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}