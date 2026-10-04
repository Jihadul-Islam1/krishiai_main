import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/states.dart';

/// Fertilizer NPK calculator.
///
/// Inputs: crop (chips), land size (decimal), soil (chips).
/// Outputs: recommended N, P, K in kg per acre + total kg for the land area,
/// plus a simple split into 3 application stages.
class FertilizerScreen extends ConsumerStatefulWidget {
  const FertilizerScreen({super.key});

  @override
  ConsumerState<FertilizerScreen> createState() => _FertilizerScreenState();
}

class _FertilizerScreenState extends ConsumerState<FertilizerScreen> {
  final _landCtrl = TextEditingController(text: '1.0');
  String _crop = 'ধান';
  String _soil = 'দোআঁশ';

  @override
  void dispose() {
    _landCtrl.dispose();
    super.dispose();
  }

  double _landSize() {
    return double.tryParse(_landCtrl.text.trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final rec = _recommend(_crop, _soil);
    final land = _landSize();
    return Scaffold(
      appBar: AppBar(title: const Text('সার নির্দেশিকা')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ফসল নির্বাচন', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  items: _crops,
                  selected: _crop,
                  onChanged: (v) => setState(() => _crop = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('মাটির ধরন', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  items: const ['দোআঁশ', 'বেলে', 'এঁটেল', 'পাহাড়ি'],
                  selected: _soil,
                  onChanged: (v) => setState(() => _soil = v),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science_rounded, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('প্রস্তাবিত সার', style: AppTextStyles.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$_crop • $_soil • ${land.toStringAsFixed(2)} একর',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                _NpkRow(label: 'নাইট্রোজেন (N)', kgPerAcre: rec.n),
                _NpkRow(label: 'ফসফরাস (P)', kgPerAcre: rec.p),
                _NpkRow(label: 'পটাশ (K)', kgPerAcre: rec.k),
                if (land > 0) ...[
                  const Divider(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _TotalTile(
                          label: 'ইউরিয়া',
                          amount: rec.urea * land,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TotalTile(
                          label: 'টিএসপি',
                          amount: rec.tsp * land,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TotalTile(
                          label: 'এমওপি',
                          amount: rec.mop * land,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ],
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
                    const Icon(Icons.event_note_rounded, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Text('প্রয়োগের সময়সূচি', style: AppTextStyles.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _StageRow(
                  stage: 'বপন/রোপণের সময়',
                  detail: 'সম্পূর্ণ ফসফরাস, সম্পূর্ণ পটাশ, ইউরিয়ার ১/৩ অংশ',
                ),
                _StageRow(
                  stage: '২০-২৫ দিন পর',
                  detail: 'ইউরিয়ার ১/৩ অংশ',
                ),
                _StageRow(
                  stage: '৪০-৫০ দিন পর',
                  detail: 'ইউরিয়ার বাকি ১/৩ অংশ',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'পরামর্শ সংরক্ষণ করুন',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('পরামর্শ সংরক্ষিত হয়েছে')),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Disclaimer(),
        ],
      ),
    );
  }

  static const _crops = [
    'ধান', 'গম', 'ভুট্টা', 'আলু', 'টমেটো', 'বেগুন', 'মরিচ', 'পেঁয়াজ',
  ];

  _Rec _recommend(String crop, String soil) {
    // baseline NPK values per acre (kg) — generic Bangladesh extension-style
    final base = switch (crop) {
      'ধান' => const _Rec(n: 60, p: 25, k: 30),
      'গম' => const _Rec(n: 55, p: 30, k: 25),
      'ভুট্টা' => const _Rec(n: 70, p: 30, k: 35),
      'আলু' => const _Rec(n: 80, p: 35, k: 70),
      'টমেটো' => const _Rec(n: 65, p: 30, k: 50),
      'বেগুন' => const _Rec(n: 55, p: 25, k: 40),
      'মরিচ' => const _Rec(n: 50, p: 25, k: 40),
      'পেঁয়াজ' => const _Rec(n: 60, p: 30, k: 45),
      _ => const _Rec(n: 50, p: 25, k: 30),
    };
    // soil modifier (very rough)
    final mod = switch (soil) {
      'দোআঁশ' => 1.0,
      'বেলে' => 1.15, // leaches, need more
      'এঁটেল' => 0.90,
      'পাহাড়ি' => 1.10,
      _ => 1.0,
    };
    final n = (base.n * mod).round();
    final p = base.p;
    final k = base.k;
    // approx conversions to common fertilizers:
    // Urea (46% N) -> N/0.46 per acre
    // TSP (46% P2O5) -> we keep P as P2O5 (very rough)
    // MoP (60% K2O)
    final urea = n / 0.46;
    final tsp = (p / 0.46).toDouble();
    final mop = (k / 0.60).toDouble();
    return _Rec(n: n.toDouble(), p: p.toDouble(), k: k.toDouble(), urea: urea, tsp: tsp, mop: mop);
  }
}

class _Rec {
  const _Rec({
    this.n = 0,
    this.p = 0,
    this.k = 0,
    this.urea = 0,
    this.tsp = 0,
    this.mop = 0,
  });
  final double n;
  final double p;
  final double k;
  final double urea;
  final double tsp;
  final double mop;
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

class _NpkRow extends StatelessWidget {
  const _NpkRow({required this.label, required this.kgPerAcre});
  final String label;
  final double kgPerAcre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: AppTextStyles.body),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (kgPerAcre / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('${kgPerAcre.toStringAsFixed(0)} কেজি/একর',
              style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text('${amount.toStringAsFixed(0)} কেজি',
              style: AppTextStyles.bodyBold.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.detail});
  final String stage;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage, style: AppTextStyles.bodyBold),
                Text(detail, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'এই পরামর্শ সাধারণ নির্দেশনামূলক। মাটি পরীক্ষার ভিত্তিতে উপজেলা কৃষি কর্মকর্তার পরামর্শ নিন।',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// LoadingState/ErrorStateView are kept imported for future async extensions.
// ignore: unused_element
const Object _kept = LoadingState;