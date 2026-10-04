import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';

/// Irrigation planner.
///
/// Inputs: crop, growth stage, soil type, weather (rain / dry / hot), land size.
/// Outputs: water requirement per day (liters) + weekly frequency.
class IrrigationScreen extends ConsumerStatefulWidget {
  const IrrigationScreen({super.key});

  @override
  ConsumerState<IrrigationScreen> createState() => _IrrigationScreenState();
}

class _IrrigationScreenState extends ConsumerState<IrrigationScreen> {
  final _landCtrl = TextEditingController(text: '1.0');
  String _crop = 'ধান';
  String _stage = 'বৃদ্ধি';
  String _soil = 'দোআঁশ';
  String _weather = 'স্বাভাবিক';

  @override
  void dispose() {
    _landCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan(_crop, _stage, _soil, _weather);
    final land = double.tryParse(_landCtrl.text.trim()) ?? 0;
    final daily = plan.daily * land;
    final weekly = plan.daily * plan.daysPerWeek * land;
    return Scaffold(
      appBar: AppBar(title: const Text('সেচ নির্দেশিকা')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ফসল ও পর্যায়', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  items: const ['ধান', 'গম', 'ভুট্টা', 'আলু', 'টমেটো', 'বেগুন'],
                  selected: _crop,
                  onChanged: (v) => setState(() => _crop = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  items: const ['চারা', 'বৃদ্ধি', 'ফুল', 'ফল'],
                  selected: _stage,
                  onChanged: (v) => setState(() => _stage = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('মাটির ধরন', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  items: const ['দোআঁশ', 'বেলে', 'এঁটেল'],
                  selected: _soil,
                  onChanged: (v) => setState(() => _soil = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('আবহাওয়া', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  items: const ['বৃষ্টি', 'স্বাভাবিক', 'গরম'],
                  selected: _weather,
                  onChanged: (v) => setState(() => _weather = v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'জমির আকার (একর)',
                  controller: _landCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.info.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded, color: AppColors.info),
                    const SizedBox(width: AppSpacing.sm),
                    Text('আজকের সেচ পরিকল্পনা', style: AppTextStyles.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'প্রতিদিন',
                        value: '${daily.toStringAsFixed(0)} লিটার',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatTile(
                        label: 'সাপ্তাহিক',
                        value: '${weekly.toStringAsFixed(0)} লিটার',
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatTile(
                        label: 'সপ্তাহে কতবার',
                        value: '${plan.daysPerWeek} দিন',
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_rounded, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Text('৭ দিনের সময়সূচি', style: AppTextStyles.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _WeekRow(plan: plan),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded,
                        color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Text('পরামর্শ', style: AppTextStyles.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final t in _tips(_stage, _weather, _soil))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(t, style: AppTextStyles.bodySecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'রিমাইন্ডার সেট করুন',
            icon: Icons.notifications_active_rounded,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('রিমাইন্ডার সংরক্ষিত হয়েছে')),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  _Plan _plan(String crop, String stage, String soil, String weather) {
    // base liters per acre per day by crop
    final base = switch (crop) {
      'ধান' => 12000.0,
      'গম' => 4500.0,
      'ভুট্টা' => 6000.0,
      'আলু' => 5000.0,
      'টমেটো' => 4500.0,
      'বেগুন' => 3500.0,
      _ => 5000.0,
    };
    final stageMult = switch (stage) {
      'চারা' => 0.6,
      'বৃদ্ধি' => 1.0,
      'ফুল' => 1.3,
      'ফল' => 1.1,
      _ => 1.0,
    };
    final soilMult = switch (soil) {
      'বেলে' => 1.3, // needs more frequent
      'দোআঁশ' => 1.0,
      'এঁটেল' => 0.85,
      _ => 1.0,
    };
    final weatherMult = switch (weather) {
      'বৃষ্টি' => 0.3,
      'স্বাভাবিক' => 1.0,
      'গরম' => 1.4,
      _ => 1.0,
    };
    final daysPerWeek = switch (weather) {
      'বৃষ্টি' => 1,
      'স্বাভাবিক' => 3,
      'গরম' => 5,
      _ => 3,
    };
    final daily = base * stageMult * soilMult * weatherMult;
    return _Plan(daily: daily, daysPerWeek: daysPerWeek);
  }

  List<String> _tips(String stage, String weather, String soil) {
    final out = <String>[];
    if (weather == 'গরম') {
      out.add('গরম আবহাওয়ায় ভোরে বা সন্ধ্যায় সেচ দিন।');
    }
    if (weather == 'বৃষ্টি') {
      out.add('বৃষ্টির পর মাটি শুকলে সেচ দিন।');
    }
    if (soil == 'বেলে') {
      out.add('বেলে মাটিতে ঘন ঘন অল্প পানি দিন।');
    }
    if (stage == 'ফুল') {
      out.add('ফুল ধরার সময় পানির ঘাটতি হলে ফলন কমে যায়।');
    }
    if (out.isEmpty) {
      out.add('সকালে সেচ দেওয়া সবচেয়ে কার্যকর।');
      out.add('সেচের পর আগাছা পরিষ্কার করুন।');
    }
    return out;
  }
}

class _Plan {
  const _Plan({required this.daily, required this.daysPerWeek});
  final double daily;
  final int daysPerWeek;
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.items,
    required this.selected,
    required this.onChanged,
  });
  final List<String> items;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: items
          .map((e) => ChoiceChip(
                label: Text(e),
                selected: e == selected,
                onSelected: (_) => onChanged(e),
                selectedColor: AppColors.primaryContainer,
                labelStyle: AppTextStyles.body.copyWith(
                  color: e == selected
                      ? AppColors.primaryDark
                      : AppColors.textPrimary,
                  fontWeight: e == selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ))
          .toList(),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value,
              style: AppTextStyles.bodyBold.copyWith(color: color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.plan});
  final _Plan plan;

  static const _days = ['শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র'];

  @override
  Widget build(BuildContext context) {
    // pick evenly-spaced days
    final step = 7 / plan.daysPerWeek;
    final picked = <int>{};
    for (var i = 0; i < plan.daysPerWeek; i++) {
      picked.add((i * step).floor() % 7);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final on = picked.contains(i);
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
              ),
              child: Icon(
                on ? Icons.water_drop_rounded : Icons.remove,
                color: on ? Colors.white : AppColors.textMuted,
                size: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _days[i],
              style: AppTextStyles.caption.copyWith(
                color: on ? AppColors.primaryDark : AppColors.textSecondary,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      }),
    );
  }
}