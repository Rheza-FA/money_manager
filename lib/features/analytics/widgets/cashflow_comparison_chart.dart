import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/analytics_models.dart';

class SpendingBenchmarkChart extends StatefulWidget {
  final List< SpendingBarPoint > points;
  final String benchmarkLabel;

  const SpendingBenchmarkChart({
    super.key,
    required this.points,
    required this.benchmarkLabel,
  });

  @override
  State< SpendingBenchmarkChart > createState() =>
      _SpendingBenchmarkChartState();
}

class _SpendingBenchmarkChartState extends State< SpendingBenchmarkChart > {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _defaultIndex();
  }

  @override
  void didUpdateWidget(covariant SpendingBenchmarkChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _selectedIndex = _defaultIndex();
    }
  }

  int _defaultIndex() {
    if (widget.points.isEmpty) return -1;
    for (int i = widget.points.length - 1; i >= 0; i--) {
      if (widget.points[i].isCurrentHighlight || widget.points[i].spent > 0) {
        return i;
      }
    }
    return widget.points.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const SizedBox(height: 160);
    }

    double maxVal = 0;
    double representativeBenchmark = 0;
    for (final SpendingBarPoint pt in widget.points) {
      maxVal = math.max(maxVal, math.max(pt.spent, pt.safeBenchmark));
      if (pt.safeBenchmark > 0) {
        representativeBenchmark = pt.safeBenchmark;
      }
    }
    if (maxVal <= 0) maxVal = 1.0;
    final double ceiling = maxVal * 1.15;

    final SpendingBarPoint selectedPoint =
        (_selectedIndex >= 0 && _selectedIndex < widget.points.length)
            ? widget.points[_selectedIndex]
            : widget.points.last;

    final double diffFromLimit =
        selectedPoint.safeBenchmark - selectedPoint.spent;
    final bool hasBenchmark = selectedPoint.safeBenchmark > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: < Widget >[
        // Panel Detail Titik yang Dipilih
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ForestAnalyticsPalette.iconBoxMint,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: < Widget >[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: < Widget >[
                  Text(
                    selectedPoint.fullDateLabel +
                        ' (' +
                        selectedPoint.transactionCount.toString() +
                        'x transaksi)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: ForestAnalyticsPalette.bodyGreyText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
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
                        IdrFormatter.numberOnly(selectedPoint.spent),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ForestAnalyticsPalette.deepForest,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasBenchmark)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selectedPoint.isOverLimit
                        ? ForestAnalyticsPalette.warningCoral
                            .withValues(alpha: 0.15)
                        : ForestAnalyticsPalette.deepForest
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    diffFromLimit >= 0
                        ? ('Hemat ' + IdrFormatter.compact(diffFromLimit))
                        : ('Lewat ' + IdrFormatter.compact(diffFromLimit.abs())),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selectedPoint.isOverLimit
                          ? ForestAnalyticsPalette.warningCoral
                          : ForestAnalyticsPalette.deepForest,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Area Grafik Batang + Garis Benchmark Putus-putus
        SizedBox(
          height: 165,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double bottomAxisHeight = 26.0;
              final double plotHeight =
                  constraints.maxHeight - bottomAxisHeight;
              final double benchmarkRatio = representativeBenchmark > 0
                  ? (representativeBenchmark / ceiling).clamp(0.0, 1.0)
                  : 0.0;
              final double benchmarkTopOffset =
                  plotHeight * (1.0 - benchmarkRatio);

              return Stack(
                clipBehavior: Clip.none,
                children: < Widget >[
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomAxisHeight,
                    child: Container(
                      height: 1,
                      color: ForestAnalyticsPalette.scaffoldMint,
                    ),
                  ),
                  if (representativeBenchmark > 0)
                    Positioned(
                      top: benchmarkTopOffset,
                      left: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: < Widget >[
                          Transform.translate(
                            offset: const Offset(0, -15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ForestAnalyticsPalette.scaffoldMint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.benchmarkLabel +
                                    ': ' +
                                    IdrFormatter.compact(
                                      representativeBenchmark,
                                    ),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: ForestAnalyticsPalette.deepForest,
                                ),
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: Size(constraints.maxWidth, 1),
                            painter: _DashedLinePainter(
                              color: ForestAnalyticsPalette.sageAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children:
                        List< Widget >.generate(widget.points.length, (int index) {
                      final SpendingBarPoint pt = widget.points[index];
                      final bool isSelected = index == _selectedIndex;
                      final double ratio = pt.spent > 0
                          ? (pt.spent / ceiling).clamp(0.06, 1.0)
                          : 0.03;

                      Color barColor;
                      if (pt.spent <= 0) {
                        barColor = ForestAnalyticsPalette.scaffoldMint;
                      } else if (pt.isOverLimit) {
                        barColor = isSelected
                            ? ForestAnalyticsPalette.warningCoral
                            : ForestAnalyticsPalette.warningCoral
                                .withValues(alpha: 0.55);
                      } else {
                        barColor = isSelected
                            ? ForestAnalyticsPalette.deepForest
                            : ForestAnalyticsPalette.sageAccent
                                .withValues(alpha: 0.65);
                      }

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selectedIndex = index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: < Widget >[
                              SizedBox(
                                height: plotHeight,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                    width: isSelected ? 22 : 18,
                                    height: plotHeight * ratio,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: bottomAxisHeight - 8,
                                child: Text(
                                  pt.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? ForestAnalyticsPalette.deepForest
                                        : ForestAnalyticsPalette.bodyGreyText,
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
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    double startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(math.min(startX + dashWidth, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}