import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/weather.dart';
import '../../providers/app_providers.dart';

/// Full weather screen — current snapshot, hourly forecast (24h),
/// 7-day forecast and agronomy advice. Rewritten on the home_dashboard
/// minimalist pattern: gradient `_Header`, `AppCard`, `IconBadge`,
/// `SectionHeader`, `AppTextStyles`.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Clear any stale demo override the moment a real fetch returns —
    // keeps the screen honest ("everything real, no demo").
    ref.listen<AsyncValue<WeatherSnapshot?>>(weatherProvider, (prev, next) {
      final override = ref.read(demoOverrideProvider);
      if (override != null && next.hasValue && next.value != null) {
        ref.read(demoOverrideProvider.notifier).state = null;
      }
    });
    final weatherAsync = ref.watch(weatherProvider);
    final demoOverride = ref.watch(demoOverrideProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: weatherAsync.when(
        loading: () => demoOverride != null
            ? _WeatherBody(snapshot: demoOverride)
            : const _LoadingShell(),
        error: (e, _) {
          final detail = e.toString();
          return ErrorStateView(
            message: 'আবহাওয়ার তথ্য লোড করা যায়নি।',
            detail: detail,
            onRetry: () {
              ref.read(demoOverrideProvider.notifier).state = null;
              ref.invalidate(weatherProvider);
            },
          );
        },
        data: (snap) => snap == null
            ? const _EmptyBody()
            : _WeatherBody(snapshot: snap),
      ),
    );
  }
}

/// Holds an explicit "show cached snapshot while retrying" override set
/// when the live fetch is in flight. Cleared automatically on the next
/// successful live fetch (see the `ref.listen` in `WeatherScreen.build`).
/// No demo data is ever injected here — the value, if any, is a snapshot
/// previously fetched live.
final demoOverrideProvider = StateProvider<WeatherSnapshot?>((_) => null);

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _kWeatherHeader,
        Expanded(
          child: LoadingState(message: 'আবহাওয়া লোড হচ্ছে...'),
        ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _kWeatherHeader,
        Expanded(
          child: EmptyState(
            icon: Icons.wb_cloudy_outlined,
            title: 'আবহাওয়ার তথ্য পাওয়া যায়নি',
            message: 'একটু পর আবার চেষ্টা করুন।',
          ),
        ),
      ],
    );
  }
}

class _WeatherBody extends ConsumerWidget {
  const _WeatherBody({required this.snapshot});
  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The repository remembers whether the last snapshot came from the
    // real Open-Meteo API or from bundled fallback data. We use that to
    // swap the fallback disclaimer for a "লাইভ" badge so the user can
    // always tell which one they're looking at.
    final repo = ref.watch(weatherRepoProvider).valueOrNull;
    final isLive = repo == null ? false : !repo.isLastDemo;
    return RefreshIndicator(
      onRefresh: () async {
        // Force a fresh fetch — repository will re-acquire GPS and re-hit
        // Open-Meteo so the screen is genuinely real-time.
        final repo = await ref.read(weatherRepoProvider.future);
        await repo.currentFromGps();
        ref.invalidate(weatherProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: _kWeatherHeader),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _CurrentCard(snapshot: snapshot, isLive: isLive),
                const SizedBox(height: AppSpacing.xxl),
                const SectionHeader(
                  eyebrow: 'TODAY',
                  title: '২৪ ঘণ্টার পূর্বাভাস',
                  subtitle: 'প্রতি ঘণ্টার তাপমাত্রা ও আবহাওয়া',
                ),
                const SizedBox(height: AppSpacing.md),
                _HourlyStrip(hourly: snapshot.hourly),
                const SizedBox(height: AppSpacing.xxl),
                const SectionHeader(
                  eyebrow: 'WEEK',
                  title: 'আগামী ৭ দিন',
                  subtitle: 'সর্বোচ্চ ও সর্বনিম্ন তাপমাত্রা',
                ),
                const SizedBox(height: AppSpacing.md),
                _DailyList(daily: snapshot.daily),
                const SizedBox(height: AppSpacing.xxl),
                const SectionHeader(
                  eyebrow: 'ADVICE',
                  title: AppStrings.todaysAdvice,
                  subtitle: 'আবহাওয়া অনুযায়ী কৃষি পরামর্শ',
                ),
                const SizedBox(height: AppSpacing.md),
                _AdviceCard(advice: snapshot.agronomyAdvice),
                // The fallback disclaimer is only relevant when we
                // genuinely couldn't fetch live data. Real-time fetches
                // show a "লাইভ" badge inside the hero card instead, so we
                // hide this footer entirely in that case.
                if (!isLive) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  const _Disclaimer(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient header uses shared `ScreenHeader`. Eyebrow "TODAY" + title
/// "আবহাওয়া"; decorative cloud icon.
const _kWeatherHeader = ScreenHeader(
  eyebrow: 'TODAY',
  title: 'আবহাওয়া',
  actionIcon: Icons.cloud_outlined,
  actionDecorative: true,
);

/// Hero current-weather card. Kept on the gradient surface (same colors as
/// the header) for the signature feel, but now wrapped in `AppCard` for
/// consistent border radius / shadow tokens.
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.snapshot, required this.isLive});
  final WeatherSnapshot snapshot;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.weatherCard, AppColors.fieldCard],
      ),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      elevation: AppElevation.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  snapshot.location,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLive) ...[
                const _LiveBadge(),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                AppDate.full(snapshot.updatedAt),
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConditionIcon(condition: snapshot.condition, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.currentTempC.round()}°',
                      style: AppTextStyles.display.copyWith(
                        color: Colors.white,
                        fontSize: 56,
                        height: 1,
                      ),
                    ),
                    Text(
                      snapshot.condition.bangla,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
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
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.water_drop_outlined,
                  label: 'আর্দ্রতা',
                  value: '${snapshot.humidity.round()}%',
                ),
                _StatChip(
                  icon: Icons.air_rounded,
                  label: 'বাতাস',
                  value: '${snapshot.windKmh.round()} km/h',
                ),
                _StatChip(
                  icon: Icons.umbrella_outlined,
                  label: 'বৃষ্টি',
                  value: '${snapshot.rainProbability.round()}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip({required this.hourly});
  final List<HourlyForecast> hourly;

  @override
  Widget build(BuildContext context) {
    if (hourly.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('ঘণ্টা ভিত্তিক তথ্য পাওয়া যায়নি', style: AppTextStyles.bodySecondary),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: hourly.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final h = hourly[i];
          return Container(
            width: 72,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatHour(h.time),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                _ConditionIcon(condition: h.condition, size: 22),
                Text(
                  '${h.tempC.round()}°',
                  style: AppTextStyles.bodyBold,
                ),
                Text(
                  '${(h.rainProbability * 100).round()}%',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatHour(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({required this.daily});
  final List<DailyForecast> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('দৈনিক তথ্য পাওয়া যায়নি', style: AppTextStyles.bodySecondary),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < daily.length; i++) ...[
            _DailyRow(day: daily[i]),
            if (i != daily.length - 1)
              const Divider(color: AppColors.divider, height: 1),
          ],
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.day});
  final DailyForecast day;

  static const _bnWeekdays = [
    'সোম',
    'মঙ্গল',
    'বুধ',
    'বৃহঃ',
    'শুক্র',
    'শনি',
    'রবি',
  ];

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(day.date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              isToday ? 'আজ' : _bnWeekdays[day.date.weekday - 1],
              style: AppTextStyles.bodyBold.copyWith(
                color: isToday ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          _ConditionIcon(condition: day.condition, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.condition.bangla,
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
                Text(
                  'বৃষ্টি ${(day.rainProbability * 100).round()}%',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(
            '${day.minTempC.round()}°',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 40,
            child: Text(
              '${day.maxTempC.round()}°',
              style: AppTextStyles.bodyBold,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});
  final String advice;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primaryContainer,
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: Icons.tips_and_updates_outlined,
            tint: AppColors.tintGreen,
            color: AppColors.primary,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              advice,
              style: AppTextStyles.body.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Disclaimer footer mirrors the safety note in `crop_doctor_screen.dart`.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: Icons.info_outline,
            tint: AppColors.tintAmber,
            color: AppColors.accentDark,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppStrings.weatherDisclaimer,
              style: AppTextStyles.caption.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionIcon extends StatelessWidget {
  const _ConditionIcon({required this.condition, this.size = 24});
  final WeatherCondition condition;
  final double size;

  IconData get _icon {
    switch (condition) {
      case WeatherCondition.rainy:
      case WeatherCondition.stormy:
        return Icons.umbrella_rounded;
      case WeatherCondition.cloudy:
        return Icons.cloud_rounded;
      case WeatherCondition.foggy:
        return Icons.cloud_outlined;
      case WeatherCondition.sunny:
      case WeatherCondition.partlyCloudy:
        return Icons.wb_sunny_rounded;
    }
  }

  Color get _color {
    switch (condition) {
      case WeatherCondition.rainy:
      case WeatherCondition.stormy:
        return AppColors.info;
      case WeatherCondition.foggy:
      case WeatherCondition.cloudy:
        return AppColors.textSecondary;
      case WeatherCondition.sunny:
      case WeatherCondition.partlyCloudy:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(_icon, color: _color, size: size);
  }
}

/// Tiny green pill rendered in the hero card's location row when the
/// current snapshot is real (came from Open-Meteo rather than any
/// fallback path). Pure decoration — no semantics beyond the label.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: Colors.greenAccent, size: 12),
          SizedBox(width: 3),
          Text(
            'লাইভ',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
