import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/rice_disease_classifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/diagnosis.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/severity_style.dart';
import 'doctor_crops.dart';

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.diagnosis,
    this.imagePath,
    this.fromScan = false,
  });

  final Diagnosis diagnosis;
  final String? imagePath;

  /// Opened right after a scan (vs. from history): "new scan" just pops back.
  final bool fromScan;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _treatmentKey = GlobalKey();

  // অনেকে বোঝেন না নিচে আরো তথ্য আছে, তাই প্রথম scroll পর্যন্ত ইঙ্গিত দেখাই
  bool _showScrollHint = true;
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // সব তথ্য এক screen-এই এঁটে গেলে ইঙ্গিতের দরকার নেই
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.position.maxScrollExtent < 48) {
        _hideScrollHint();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.offset > 48) _hideScrollHint();
  }

  void _hideScrollHint() {
    if (!_showScrollHint || !mounted) return;
    _bounce.stop();
    setState(() => _showScrollHint = false);
  }

  void _scrollToTreatment() {
    _hideScrollHint();
    final target = _treatmentKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
      // pinned app bar Flutter নিজেই হিসাবে ধরে; শুধু সামান্য ফাঁক রাখা
      alignment: 0.04,
    );
  }

  /// "নিচে করণীয়, সার ও প্রতিরোধ দেখুন" — শুধু যে অংশগুলো আছে সেগুলোর নাম
  String get _hintLabel {
    final d = widget.diagnosis;
    final parts = [
      if (d.management.isNotEmpty) 'করণীয়',
      if (d.fertilizer.isNotEmpty) 'সার',
      if (d.prevention.isNotEmpty) 'প্রতিরোধ',
    ];
    if (parts.isEmpty) return 'নিচে আরো তথ্য আছে';
    final joined = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join(', ')} ও ${parts.last}';
    return 'নিচে $joined দেখুন';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diagnosis;
    final crop = DoctorCrop.byName(d.cropName);
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              _ResultAppBar(
                crop: crop,
                imagePath: widget.imagePath ?? d.imagePath,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                sliver: SliverList.list(
                  children: [
                    _SummaryCard(diagnosis: d),
                    if (d.notes != null || d.alternatives.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _CautionCard(diagnosis: d),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _InfoSection(
                      title: 'লক্ষণ',
                      subtitle: 'আপনার পাতার সাথে মিলিয়ে দেখুন',
                      icon: Icons.visibility_outlined,
                      tint: AppColors.tintViolet,
                      color: const Color(0xFF7C3AED),
                      items: d.symptoms,
                    ),
                    _InfoSection(
                      key: _treatmentKey,
                      title: 'করণীয় ও চিকিৎসা',
                      subtitle: 'এখনই যা করবেন',
                      icon: Icons.medical_services_outlined,
                      tint: AppColors.tintGreen,
                      color: AppColors.primary,
                      items: d.management,
                      numbered: true,
                      highlighted: true,
                    ),
                    _InfoSection(
                      title: 'সার ব্যবস্থাপনা',
                      icon: Icons.eco_outlined,
                      tint: AppColors.accentLight,
                      color: AppColors.accentDark,
                      items: d.fertilizer,
                      footer: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/fertilizer'),
                          icon: const Icon(Icons.calculate_outlined, size: 18),
                          label: const Text('জমি অনুযায়ী সারের হিসাব করুন'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentDark,
                            side: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                    _InfoSection(
                      title: 'প্রতিরোধ',
                      subtitle: 'পরের বার যেন না হয়',
                      icon: Icons.shield_outlined,
                      tint: AppColors.tintBlue,
                      color: AppColors.info,
                      items: d.prevention,
                    ),
                    _InfoSection(
                      title: 'কারণ',
                      icon: Icons.bug_report_outlined,
                      tint: AppColors.tintRed,
                      color: AppColors.danger,
                      items: d.causes,
                    ),
                    const _Disclaimer(),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_showScrollHint,
              child: AnimatedOpacity(
                opacity: _showScrollHint ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _ScrollHint(
                  color: crop.deepColor,
                  label: _hintLabel,
                  bounce: _bounce,
                  onTap: _scrollToTreatment,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: 'নতুন স্ক্যান করুন',
          icon: Icons.photo_camera_rounded,
          background: crop.color,
          onPressed: () => widget.fromScan
              ? context.pop()
              : context.pushReplacement('/ai/scan?crop=${crop.id}'),
        ),
      ),
    );
  }
}

/// Pill with a bouncing arrow over a soft fade, telling the farmer the
/// treatment advice continues below the fold. Tap jumps to it.
class _ScrollHint extends StatelessWidget {
  const _ScrollHint({
    required this.color,
    required this.label,
    required this.bounce,
    required this.onTap,
  });

  final Color color;
  final String label;
  final Animation<double> bounce;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // fade শুধু দেখানোর জন্য; touch নিচের list-এ যাক যাতে scroll আটকায় না
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg.withValues(alpha: 0), bg],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Material(
              color: color,
              shape: const StadiumBorder(),
              elevation: AppElevation.floating,
              shadowColor: color.withValues(alpha: 0.4),
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm + 2,
                    AppSpacing.md,
                    AppSpacing.sm + 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AnimatedBuilder(
                        animation: bounce,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, 3 * bounce.value),
                          child: child,
                        ),
                        child: const Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsing header with the scanned leaf; plain bar when there's no photo.
class _ResultAppBar extends StatelessWidget {
  const _ResultAppBar({required this.crop, required this.imagePath});

  final DoctorCrop crop;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null) {
      return const SliverAppBar(
        pinned: true,
        centerTitle: true,
        title: Text('রোগ নির্ণয় ফলাফল'),
      );
    }
    return SliverAppBar(
      pinned: true,
      expandedHeight: 250,
      centerTitle: true,
      backgroundColor: crop.deepColor,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: const Text('রোগ নির্ণয় ফলাফল'),
      leading: IconButton(
        tooltip: 'ফিরে যান',
        onPressed: () => context.pop(),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.28),
        ),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // History-তে পুরোনো ছবি cache থেকে মুছে যেতে পারে
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [crop.deepColor, crop.color],
                  ),
                ),
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: AppColors.textOnDarkMuted,
                ),
              ),
            ),
            // উপরে-নিচে হালকা ছায়া, যাতে সাদা লেখা ছবির ওপর পড়া যায়
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x80000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x4D000000),
                  ],
                  stops: [0, 0.32, 0.7, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.diagnosis});

  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final d = diagnosis;
    final (nameBn, nameEn) = _splitDiseaseName(d.diseaseName);
    // সুস্থ পাতার জন্য "ঝুঁকি" না বলে সরাসরি "সুস্থ"
    final healthy = d.diseaseName.contains('সুস্থ');
    final crop = DoctorCrop.byName(d.cropName);
    final confident =
        d.isConfident ??
        d.confidence >= RiceDiseaseClassifier.confidentThreshold;
    final statusColor = confident ? AppColors.primary : AppColors.accentDark;

    return AppCard(
      elevation: AppElevation.raised,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                icon: healthy ? Icons.check_circle_rounded : d.severity.icon,
                label: healthy ? 'সুস্থ' : d.severity.riskLabel,
                color: d.severity.color,
                tint: d.severity.tint,
              ),
              const SizedBox(width: AppSpacing.xs),
              _Pill(
                emoji: crop.emoji,
                label: d.cropName,
                color: crop.deepColor,
                tint: crop.tint,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppDate.relativeBangla(d.scannedAt),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nameBn, style: AppTextStyles.h2),
                    if (nameEn != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      // বাংলা নামের সমান আকারে, যাতে ইংরেজি নামও সহজে পড়া যায়
                      Text(
                        nameEn,
                        style: AppTextStyles.h2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _ConfidenceRing(value: d.confidence, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: confident
                  ? AppColors.primaryContainer
                  : AppColors.tintAmber,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  confident
                      ? Icons.verified_rounded
                      : Icons.help_outline_rounded,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    confident
                        ? 'এআই এই ফলাফলে আত্মবিশ্বাসী'
                        : 'ফলাফল নিশ্চিত নয়, আরেকটি ছবি দিয়ে মিলিয়ে নিন',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
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

/// "পাতা ব্লাস্ট রোগ (Leaf Blast)" → ("পাতা ব্লাস্ট রোগ", "Leaf Blast")
(String, String?) _splitDiseaseName(String name) {
  final m = RegExp(r'^(.*)\s\(([^()]*)\)$').firstMatch(name);
  return m == null ? (name, null) : (m.group(1)!, m.group(2));
}

class _Pill extends StatelessWidget {
  const _Pill({
    this.icon,
    this.emoji,
    required this.label,
    required this.color,
    required this.tint,
  });

  final IconData? icon;

  /// Shown instead of [icon], e.g. the crop's 🍅.
  final String? emoji;
  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 13))
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular gauge that fills up to the model's confidence on first build.
class _ConfidenceRing extends StatelessWidget {
  const _ConfidenceRing({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(color),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${AppNumber.bangla((v * 100).round())}%',
                    style: AppTextStyles.title.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Text(
                    'আত্মবিশ্বাস',
                    style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CautionCard extends StatelessWidget {
  const _CautionCard({required this.diagnosis});

  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final notes = diagnosis.notes?.split('\n') ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.tintAmber,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(
                icon: Icons.info_outline_rounded,
                tint: Colors.white,
                color: AppColors.accentDark,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Text(
                'সতর্কতা',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.accentDark,
                ),
              ),
            ],
          ),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                note,
                style: AppTextStyles.body.copyWith(fontSize: 14, height: 1.4),
              ),
            ),
          if (diagnosis.alternatives.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'অন্য সম্ভাবনা',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accentDark,
              ),
            ),
            for (final alt in diagnosis.alternatives)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _splitDiseaseName(alt.name).$1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: alt.confidence,
                          minHeight: 6,
                          backgroundColor: Colors.white,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${AppNumber.bangla((alt.confidence * 100).round())}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    super.key,
    required this.title,
    required this.icon,
    required this.tint,
    required this.color,
    required this.items,
    this.subtitle,
    this.numbered = false,
    this.highlighted = false,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color tint;
  final Color color;
  final List<String> items;

  /// Show steps as ১, ২, ৩ instead of bullets.
  final bool numbered;

  /// Coloured border for the section the farmer should act on first.
  final bool highlighted;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        bordered: highlighted,
        borderColor: color.withValues(alpha: 0.35),
        elevation: highlighted ? AppElevation.card : AppElevation.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconChip(icon: icon, tint: tint, color: color, size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleLarge),
                      if (subtitle != null)
                        Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final (i, item) in items.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm + 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (numbered)
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tint,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          AppNumber.bangla(i + 1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.fromLTRB(7, 8, 8, 0),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.lg),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.gpp_maybe_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              'এটি এআই-এর অনুমান, চূড়ান্ত রোগ নির্ণয় নয়। কীটনাশক বা '
              'ছত্রাকনাশক ব্যবহারের আগে উপজেলা কৃষি অফিসারের পরামর্শ নিন '
              'এবং বোতলের লেবেলের মাত্রা মেনে চলুন।',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
