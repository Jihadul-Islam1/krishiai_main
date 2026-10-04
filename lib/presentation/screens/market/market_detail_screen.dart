import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/market_price.dart';
import '../../providers/app_providers.dart';

/// Full detail view for a single [MarketPrice] — header, 14-day chart,
/// favorite toggle, related crops, and source disclaimer.
class MarketDetailScreen extends ConsumerWidget {
  const MarketDetailScreen({super.key, required this.priceId});

  final String priceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceAsync = ref.watch(_marketPriceProvider(priceId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(AppStrings.marketDetails, style: AppTextStyles.titleLarge),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        top: false,
        child: priceAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorStateView(message: e.toString()),
          data: (price) {
            if (price == null) {
              return const _NotFound();
            }
            return _DetailBody(price: price);
          },
        ),
      ),
    );
  }
}

/// Family provider that reuses the loaded market list when possible and
/// falls back to a direct [MarketRepository.byId] lookup. Invalidate the
/// base providers after a favorite toggle so this refreshes too.
final _marketPriceProvider = FutureProvider.family<MarketPrice?, String>((
  ref,
  id,
) async {
  final repo = await ref.watch(marketRepoProvider.future);
  final farmer = await ref.watch(currentFarmerProvider.future);
  final district = farmer?.district ?? 'ঢাকা';
  // Prefer the in-memory list (cheap, already loaded by the tab).
  final all = await ref.watch(marketPricesProvider.future);
  for (final m in all) {
    if (m.id == id) return m;
  }
  // Cold-open: try the repo directly.
  return repo.byId(id, district);
});

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.price});

  final MarketPrice price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = price.trend;
    final trendColor = trend == PriceTrend.up
        ? AppColors.severityHigh
        : trend == PriceTrend.down
        ? AppColors.success
        : AppColors.warning;
    final trendIcon = trend == PriceTrend.up
        ? Icons.arrow_upward
        : trend == PriceTrend.down
        ? Icons.arrow_downward
        : Icons.remove;
    final trendLabel = trend == PriceTrend.up
        ? AppStrings.marketTrendUp
        : trend == PriceTrend.down
        ? AppStrings.marketTrendDown
        : AppStrings.marketTrendStable;
    final changed = price.changePercent;
    final allPrices = ref.watch(marketPricesProvider).valueOrNull ?? const [];
    final related = allPrices
        .where((m) => m.category == price.category && m.id != price.id)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        _HeaderCard(
          price: price,
          trendIcon: trendIcon,
          trendLabel: trendLabel,
          trendColor: trendColor,
          changePercent: changed,
          onFavorite: () => _toggleFavorite(context, ref),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (price.history.length >= 2) ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF064E3B), Color(0xFF065F46)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF022C22).withValues(alpha: 0.40),
                  blurRadius: 22,
                  spreadRadius: -6,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.marketChart14Day,
                  style: AppTextStyles.h3.copyWith(
                    color: const Color(0xFFD1FAE5),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 180,
                  child: _PriceChart(history: price.history),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (related.isNotEmpty) ...[
          Text(
            AppStrings.marketRelated,
            style: AppTextStyles.h3.copyWith(color: const Color(0xFF064E3B)),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final m in related.take(6)) _RelatedTile(price: m),
          const SizedBox(height: AppSpacing.lg),
        ],
        _SourceDisclaimer(price: price),
      ],
    );
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final repo = await ref.read(marketRepoProvider.future);
    final updated = await repo.toggleFavorite(price);
    ref.invalidate(marketPricesProvider);
    ref.invalidate(marketFavoritesProvider);
    ref.invalidate(_marketPriceProvider(price.id));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          updated.isFavorite
              ? 'প্রিয় তালিকায় যোগ হলো'
              : 'প্রিয় থেকে সরানো হলো',
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.price,
    required this.trendIcon,
    required this.trendLabel,
    required this.trendColor,
    required this.changePercent,
    required this.onFavorite,
  });

  final MarketPrice price;
  final IconData trendIcon;
  final String trendLabel;
  final Color trendColor;
  final double changePercent;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final updated = AppDate.relativeBangla(price.updatedAt);
    final minPrice = price.minPrice ?? price.currentPrice * 0.93;
    final maxPrice = price.maxPrice ?? price.currentPrice * 1.07;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.55, 1.0],
          colors: [Color(0xFF065F46), Color(0xFF064E3B), Color(0xFF022C22)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF022C22).withValues(alpha: 0.45),
            blurRadius: 26,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF34D399).withValues(alpha: 0.14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF10B981), Color(0xFF047857)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF022C22,
                            ).withValues(alpha: 0.45),
                            blurRadius: 14,
                            spreadRadius: -4,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        price.cropName.characters.first,
                        style: AppTextStyles.h2.copyWith(
                          color: const Color(0xFFD1FAE5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            price.cropName,
                            style: AppTextStyles.h2.copyWith(
                              color: const Color(0xFFD1FAE5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${price.market} • ${price.category}',
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: const Color(0xFFA7F3D0),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onFavorite,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            price.isFavorite ? Icons.star : Icons.star_border,
                            color: price.isFavorite
                                ? const Color(0xFFFACC15)
                                : const Color(0xFFD1FAE5),
                            size: AppSizes.iconXl - 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.marketPriceLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFFA7F3D0),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '৳${price.currentPrice.toStringAsFixed(0)}',
                          style: AppTextStyles.display.copyWith(
                            color: const Color(0xFFF0FDF4),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppStrings.marketPerUnit} ${price.unit}',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFFA7F3D0),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _TrendBadge(
                      icon: trendIcon,
                      label:
                          '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}% • $trendLabel',
                      color: trendColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: const Color(0xFFA7F3D0).withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetaCell(
                          label: AppStrings.marketPreviousLabel,
                          value: '৳${price.previousPrice.toStringAsFixed(0)}',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        color: const Color(0xFFA7F3D0).withValues(alpha: 0.20),
                      ),
                      Expanded(
                        child: _MetaCell(
                          label: AppStrings.marketMinMax,
                          value:
                              '৳${minPrice.toStringAsFixed(0)} - ৳${maxPrice.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${AppStrings.marketUpdated}: $updated',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFFA7F3D0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: const Color(0xFFA7F3D0)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            color: const Color(0xFFF0FDF4),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.history});

  final List<PricePoint> history;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].price));
    }
    final prices = history.map((p) => p.price).toList(growable: false);
    final rawMin = prices.reduce((a, b) => a < b ? a : b);
    final rawMax = prices.reduce((a, b) => a > b ? a : b);
    final pad = ((rawMax - rawMin).abs() < 1) ? 1.0 : (rawMax - rawMin) * 0.15;
    final minY = (rawMin - pad).clamp(0.0, double.infinity).toDouble();
    final maxY = rawMax + pad;
    final maxX = (history.length - 1).toDouble().clamp(0.0, double.infinity);
    final lineColor = const Color(0xFF34D399);
    final fillColor = const Color(0xFF10B981).withValues(alpha: 0.30);
    final axisColor = const Color(0xFFA7F3D0).withValues(alpha: 0.45);
    final tooltipBg = const Color(0xFF022C22);
    final yInterval = ((maxY - minY) / 4).clamp(0.5, double.infinity);
    final yLeftInterval = ((maxY - minY) / 3).clamp(0.5, double.infinity);
    final bottomInterval = history.length <= 7
        ? 1.0
        : (history.length / 4).ceilToDouble();
    final bottomStride = history.length <= 7 ? 1 : 4;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: axisColor, strokeWidth: 1, dashArray: const [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yLeftInterval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Text(
                  '৳${value.toStringAsFixed(0)}',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFFA7F3D0),
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: bottomInterval,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= history.length) {
                  return const SizedBox.shrink();
                }
                if (i % bottomStride != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    AppDate.short(history[i].date),
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFFA7F3D0),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tooltipBg,
            tooltipRoundedRadius: AppRadius.sm,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            getTooltipItems: (touched) => touched
                .map(
                  (s) => LineTooltipItem(
                    '৳${s.y.toStringAsFixed(0)}',
                    AppTextStyles.caption.copyWith(
                      color: const Color(0xFFD1FAE5),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) =>
                  spot.x == 0 || spot.x == history.length - 1,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: lineColor,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [fillColor, fillColor.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.price});
  final MarketPrice price;

  @override
  Widget build(BuildContext context) {
    final trend = price.trend;
    final trendColor = trend == PriceTrend.up
        ? AppColors.severityHigh
        : trend == PriceTrend.down
        ? AppColors.success
        : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064E3B), Color(0xFF065F46)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF022C22).withValues(alpha: 0.30),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: () => context.push('/market/${price.id}'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            splashColor: const Color(0xFF10B981).withValues(alpha: 0.18),
            highlightColor: const Color(0xFF10B981).withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF10B981), Color(0xFF047857)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Color(0xFFD1FAE5),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      price.cropName,
                      style: AppTextStyles.body.copyWith(
                        color: const Color(0xFFD1FAE5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '৳${price.currentPrice.toStringAsFixed(0)}',
                    style: AppTextStyles.body.copyWith(
                      color: const Color(0xFFF0FDF4),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    trend == PriceTrend.up
                        ? Icons.arrow_upward
                        : trend == PriceTrend.down
                        ? Icons.arrow_downward
                        : Icons.remove,
                    size: AppSizes.iconSm,
                    color: trendColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceDisclaimer extends StatelessWidget {
  const _SourceDisclaimer({required this.price});
  final MarketPrice price;

  @override
  Widget build(BuildContext context) {
    final isDam = price.source.toUpperCase() == 'DAM';
    final sourceLabel = isDam
        ? AppStrings.marketSourceDam
        : AppStrings.marketSourceBundled;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF022C22).withValues(alpha: 0.30),
            blurRadius: 16,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isDam ? Icons.cloud_done_outlined : Icons.info_outline,
                  size: AppSizes.iconSm,
                  color: const Color(0xFFD1FAE5),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${AppStrings.marketSource}: $sourceLabel',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: const Color(0xFFD1FAE5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.marketDisclaimer,
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFFA7F3D0),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();
  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: AppStrings.marketNoResults,
      icon: Icons.shopping_basket_outlined,
    );
  }
}
