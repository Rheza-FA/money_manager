import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _resolveInitialIndex();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
      if (_scrollPosition != position) {
        setState(() {
          _scrollPosition = position;
        });
      }
    });
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
    final bool isBiWeekly = widget.snapshot.isBiWeeklyMode;

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
      statusLine =
          isBiWeekly ? l10n.safeBudgetBiWeekly : l10n.safeBudgetMonthly;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: _scrollPosition ?? const AlwaysStoppedAnimation< double >(0.0),
        builder: (BuildContext context, Widget? child) {
          final double offset = _scrollPosition?.pixels ?? 0.0;
          final double translateY = (offset * 0.10).clamp(-15.0, 15.0);

          return Transform.translate(
            offset: Offset(0, translateY),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: < BoxShadow >[
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              padding: const EdgeInsets.all(28),
              color: AppColors.primaryDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: < Widget >[
                  // 1. Baris Header: Warna, Ketebalan, & Intensitas 100% Identik DailyLimitCard
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: < Widget >[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: < Widget >[
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: AppColors.accentGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activePoint != null
                                ? l10n.analyticsPacePrefix(
                                    activePoint.contextTitle.toUpperCase(),
                                  )
                                : l10n.analyticsSpendingPace,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onToggleSpendingMode?.call();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: < Widget >[
                              Icon(
                                isBiWeekly
                                    ? Icons.view_week_rounded
                                    : Icons.calendar_today_rounded,
                                color: AppColors.white.withValues(alpha: 0.9),
                                size: 12,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isBiWeekly
                                    ? l10n.fourteenDays
                                    : l10n.fullMonth,
                                style: TextStyle(
                                  color: AppColors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // 2. Nominal Utama: RichText Identik DailyLimitCard (White 0.7 w600 + White w800)
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(),
                      children: < InlineSpan >[
                        TextSpan(
                          text: 'Rp ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        TextSpan(
                          text: IdrFormatter.numberOnly(headlineAmount),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // 3. Sub-teks Footer: White 0.7, fontSize 12, FontWeight.w500 Identik DailyLimitCard
                  Text(
                    statusLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Grafik Batang Interaktif dengan Kontras Terang
                  if (series.isNotEmpty)
                    _buildInteractiveBars(series, benchmark),
                ],
              ),
            ),
          ),
        ),
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
                      color: AppColors.accentGreen.withValues(alpha: 0.55),
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
                    barFill = AppColors.white.withValues(alpha: 0.14);
                  } else if (pt.isOverLimit) {
                    barFill = isSelected
                        ? ForestTokens.coralAlert
                        : ForestTokens.coralAlert.withValues(alpha: 0.65);
                  } else {
                    barFill = isSelected
                        ? AppColors.accentGreen
                        : AppColors.white.withValues(alpha: 0.45);
                  }

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIndex = idx);
                      },
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
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.white.withValues(alpha: 0.95)
                                    : AppColors.white.withValues(alpha: 0.7),
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