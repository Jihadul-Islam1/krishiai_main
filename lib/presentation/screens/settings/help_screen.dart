import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_divider.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_header.dart';

/// Static Bangla FAQ + contact screen. Uses the shared header card,
/// SectionHeader + AppCard pattern shared with settings / notifications.
const _kHelpHeader = ScreenHeader(
  eyebrow: AppStrings.helpEyebrow,
  title: AppStrings.helpTitle,
  leadingIcon: Icons.support_agent_rounded,
  gradient: [AppColors.scaffoldDark, AppColors.notificationCard],
);

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = <_FaqItem>[
    _FaqItem(
      q: 'AI চিকিৎসক কতটুকু নির্ভরযোগ্য?',
      a:
          'AI মডেল ডেমো পর্যায়ে আছে। ফলাফল সবসময় ১০০% নির্ভুল নয় — গুরুতর সমস্যায় '
          'আপনার এলাকার উপজেলা কৃষি কর্মকর্তার পরামর্শ নিন।',
    ),
    _FaqItem(
      q: 'আবহাওয়ার তথ্য কি লাইভ?',
      a:
          'ডেমো ভার্সনে নির্বাচিত এলাকার জন্য পূর্বনির্ধারিত (seed) আবহাওয়া দেখানো হয়। '
          'প্রোডাকশনে বাংলাদেশ আবহাওয়া অধিদপ্তরের API সংযুক্ত করা হবে।',
    ),
    _FaqItem(
      q: 'আমার ফসলের তথ্য কি সংরক্ষিত হয়?',
      a:
          'সমস্ত তথ্য আপনার ফোনেই স্থানীয়ভাবে সংরক্ষিত থাকে (SharedPreferences)। '
          'কোনো সার্ভারে পাঠানো হয় না — লগ আউট করলে সব মুছে যায়।',
    ),
    _FaqItem(
      q: 'প্রিমিয়াম প্ল্যানে কী সুবিধা?',
      a:
          'প্রিমিয়াম মেম্বাররা পান বিস্তারিত বাজার বিশ্লেষণ, ৩০ দিনের আবহাওয়ার পূর্বাভাস, '
          'AI সহকারীতে বর্ধিত বার্তার সীমা এবং রোগ শনাক্তকরণের উন্নত রিপোর্ট।',
    ),
    _FaqItem(
      q: 'অফলাইনে কি ব্যবহার করা যায়?',
      a:
          'রোগ শনাক্তকরণ, AI সহকারীর ইতিহাস এবং সংরক্ষিত কৃষি পরামর্শ অফলাইনে দেখা যায়। '
          'বাজারদর ও লাইভ আবহাওয়ার জন্য ইন্টারনেট প্রয়োজন।',
    ),
    _FaqItem(
      q: 'ভয়েস ইনপুট কাজ করছে না, কী করব?',
      a:
          'সেটিংস থেকে মাইক্রোফোন অনুমতি পুনরায় দিন। '
          'নীরব পরিবেশে কথা বলুন এবং বাংলায় স্পষ্ট উচ্চারণে বলুন।',
    ),
    _FaqItem(
      q: 'আমি কি আমার ছবি AI-কে পাঠাতে পারব?',
      a:
          'হ্যাঁ — ক্যামেরা বা গ্যালারি থেকে সরাসরি ছবি তুলে পাঠাতে পারবেন। '
          'ছবি শুধু আপনার ফোনেই প্রক্রিয়া হয়, কোথাও আপলোড হয় না।',
    ),
    _FaqItem(
      q: 'অ্যাপ কি বাংলা ছাড়া অন্য ভাষায়?',
      a:
          'এই ডেমো শুধু বাংলায়। ইংরেজি সংস্করণ শীঘ্রই আসছে।',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _kHelpHeader,
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge,
              ),
              children: [
                const SizedBox(height: AppSpacing.lg),
                // --------------- FAQ ---------------
                const SectionHeader(
                  eyebrow: 'HELP',
                  title: AppStrings.helpFaqHeader,
                  subtitle: AppStrings.helpHeaderSubtitle,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  elevation: AppElevation.card,
                  child: Column(
                    children: [
                      for (var i = 0; i < _faqs.length; i++) ...[
                        _FaqTile(item: _faqs[i]),
                        if (i < _faqs.length - 1) const AppDivider(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // --------------- Contact ---------------
                const SectionHeader(
                  eyebrow: 'CONTACT',
                  title: AppStrings.helpContactHeader,
                  subtitle: AppStrings.helpHeaderSubtitle,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  elevation: AppElevation.card,
                  child: Column(
                    children: [
                      _ContactRow(
                        icon: Icons.email_outlined,
                        tint: AppColors.tintBlue,
                        color: AppColors.info,
                        title: AppStrings.helpContactEmailLabel,
                        subtitle: 'support@krishiai.app',
                        onTap: () => _copy(context, 'support@krishiai.app'),
                      ),
                      const AppDivider(),
                      _ContactRow(
                        icon: Icons.phone_outlined,
                        tint: AppColors.tintGreen,
                        color: AppColors.primary,
                        title: AppStrings.helpContactPhoneLabel,
                        subtitle: '+৮৮০ ১৭০০-১২৩৪৫৬',
                        onTap: () => _copy(context, '+৮৮০ ১৭০০-১২৩৪৫৬'),
                      ),
                      const AppDivider(),
                      _ContactRow(
                        icon: Icons.public_rounded,
                        tint: AppColors.tintViolet,
                        color: AppColors.primary,
                        title: AppStrings.helpContactWebsiteLabel,
                        subtitle: 'krishiai.app',
                        onTap: () => _copy(context, 'https://krishiai.app'),
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

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('কপি হয়েছে: $value')),
    );
  }
}

// ============================================================
// _FaqItem — question / answer pair kept as a value type so the
// FAQ list is data-driven.
// ============================================================
class _FaqItem {
  const _FaqItem({required this.q, required this.a});
  final String q;
  final String a;
}

// ============================================================
// _FaqTile — themed ExpansionTile inside an AppCard group.
// ============================================================
class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashFactory: InkSparkle.splashFactory,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
        ),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textSecondary,
        title: Text(item.q, style: AppTextStyles.title),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.a,
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _ContactRow — IconBadge leading + title / subtitle + trailing
// action arrow, shared with settings nav rows.
// ============================================================
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.tint,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            IconBadge(
              icon: icon,
              tint: tint,
              color: color,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
