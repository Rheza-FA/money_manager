import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/theme/app_colors.dart';
import '../models/analytics_models.dart';

class ForestPaceHeroCard extends StatefulWidget {
  final AnalyticsSnapshot snapshot;
  final VoidCallback? onToggleSpendingMode;

  const ForestPaceHeroCard({
    super.key,
    required this.snapshot,
    this.onToggleSpendingMode,
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
      statusLine = widget.snapshot.isBiWeeklyMode
          ? l10n.safeBudgetBiWeekly
          : l10n.safeBudgetMonthly;
    }

    final String cycleLabel =
        widget.snapshot.isBiWeeklyMode ? l10n.fourteenDays : l10n.fullMonth;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: < Widget >[
          // Baris Atas: Ikon + Label Abu-abu Sage + Tombol Cycle Mode Identik DailyLimitCard
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: < Widget >[
              Row(
                children: < Widget >[
                  const Icon(
                    Icons.monetization_on,
                    size: 20,
                    color: ForestTokens.mintAccent,
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
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: widget.onToggleSpendingMode,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: < Widget >[
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.greyText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cycleLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Baris Nominal Utama: "Rp" Regular GreyText + Angka Bold Putih
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
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.greyText,
                  ),
                ),
                Text(
                  IdrFormatter.numberOnly(headlineAmount),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Sub-teks Regular GreyText
          Text(
            statusLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.greyText,
            ),
          ),
          const SizedBox(height: 22),

          // Grafik Batang Interaktif
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
      height: 112,
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
                      color: ForestTokens.mintAccent.withValues(alpha: 0.40),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List< Widget >.generate(series.length, (int idx) {
                  final PaceBarPoint pt = series[idx];
                  final bool isSelected = idx == _selectedIndex;
                  final double heightFactor = pt.spent > 0
                      ? (pt.spent / ceiling).clamp(0.10, 1.0)
                      : 0.06;

                  Color barFill;
                  if (pt.spent <= 0) {
                    barFill = AppColors.white.withValues(alpha: 0.08);
                  } else if (pt.isOverLimit) {
                    barFill = isSelected
                        ? ForestTokens.coralAlert
                        : ForestTokens.coralAlert.withValues(alpha: 0.55);
                  } else {
                    barFill = isSelected
                        ? AppColors.white
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
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOutCubic,
                                width: isSelected ? 22 : 18,
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
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.greyText,
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