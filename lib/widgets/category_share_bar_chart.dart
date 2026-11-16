import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class CategoryBarData {
  const CategoryBarData({
    required this.id,
    required this.label,
    required this.count,
    required this.color,
  });

  final String id;
  final String label;
  final int count;
  final Color color;
}

double categoryShareOf(int count, int total) {
  if (total <= 0) {
    return 0;
  }
  return count / total;
}

String categoryShareLabel(int count, int total) {
  final pct = categoryShareOf(count, total) * 100;
  final rounded = (pct * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return '${rounded.round()}%';
  }
  return '${rounded.toStringAsFixed(1)}%';
}

class CategoryShareBarChart extends StatelessWidget {
  const CategoryShareBarChart({
    super.key,
    required this.bars,
    required this.selectedId,
    required this.onSelect,
    required this.countLabel,
    this.keyPrefix = 'category-bar',
  });

  final List<CategoryBarData> bars;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final String Function(int count) countLabel;
  final String keyPrefix;

  int get _total => bars.fold<int>(0, (sum, bar) => sum + bar.count);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final total = _total;
    final maxShare = bars
        .map((bar) => categoryShareOf(bar.count, total))
        .fold<double>(0, (value, share) => share > value ? share : value);
    final axisMax = _niceCeiling(maxShare);
    final ticks = _ticks(axisMax);

    return SizedBox(
      height: 228,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (var i = ticks.length - 1; i >= 0; i--)
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Text(
                              '${(ticks[i] * 100).round()}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary(brightness),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 52),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          for (var i = ticks.length - 1; i >= 0; i--)
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: AppColors.border(brightness),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final bar in bars)
                            Expanded(
                              child: _BarColumn(
                                id: bar.id,
                                label: bar.label,
                                shareLabel: categoryShareLabel(bar.count, total),
                                share: categoryShareOf(bar.count, total),
                                axisMax: axisMax,
                                selected: selectedId == bar.id,
                                color: bar.color,
                                keyPrefix: keyPrefix,
                                onTap: () => onSelect(bar.id),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      for (final bar in bars)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(bar.id),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  bar.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selectedId == bar.id
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: selectedId == bar.id
                                        ? bar.color
                                        : AppColors.textPrimary(brightness),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  countLabel(bar.count),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary(brightness),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _niceCeiling(double value) {
    if (value <= 0) {
      return 1;
    }
    if (value <= 0.2) {
      return 0.2;
    }
    if (value <= 0.25) {
      return 0.25;
    }
    if (value <= 0.4) {
      return 0.4;
    }
    if (value <= 0.5) {
      return 0.5;
    }
    if (value <= 0.6) {
      return 0.6;
    }
    if (value <= 0.8) {
      return 0.8;
    }
    return 1;
  }

  static List<double> _ticks(double axisMax) {
    if (axisMax <= 0.25) {
      return const [0, 0.1, 0.2, 0.25];
    }
    if (axisMax <= 0.4) {
      return const [0, 0.1, 0.2, 0.3, 0.4];
    }
    if (axisMax <= 0.5) {
      return const [0, 0.1, 0.2, 0.3, 0.4, 0.5];
    }
    if (axisMax <= 0.6) {
      return const [0, 0.2, 0.4, 0.6];
    }
    if (axisMax <= 0.8) {
      return const [0, 0.2, 0.4, 0.6, 0.8];
    }
    return const [0, 0.25, 0.5, 0.75, 1];
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.id,
    required this.label,
    required this.shareLabel,
    required this.share,
    required this.axisMax,
    required this.selected,
    required this.color,
    required this.keyPrefix,
    required this.onTap,
  });

  final String id;
  final String label;
  final String shareLabel;
  final double share;
  final double axisMax;
  final bool selected;
  final Color color;
  final String keyPrefix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fraction = axisMax <= 0 ? 0.0 : (share / axisMax).clamp(0.0, 1.0);
        final barHeight = constraints.maxHeight * fraction;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Semantics(
            button: true,
            selected: selected,
            label: '$label $shareLabel',
            child: KeyedSubtree(
              key: ValueKey<String>('$keyPrefix-$id'),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 28 : 22,
                  height: barHeight < 8 && share > 0 ? 8 : barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withValues(alpha: 0.72),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    border: selected
                        ? Border.all(color: color, width: 2.4)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.38),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : const [],
                  ),
                  alignment: Alignment.topCenter,
                  child: barHeight >= 22
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            shareLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : share > 0
                      ? Transform.translate(
                          offset: const Offset(0, -16),
                          child: Text(
                            shareLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
