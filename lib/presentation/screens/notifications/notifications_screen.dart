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
import '../../../core/widgets/states.dart';
import '../../../data/models/app_notification.dart';
import '../../providers/app_providers.dart';

/// Notifications inbox. Backed by `NotificationRepository` via
/// `notificationsProvider`. Tapping an unread notification marks it
/// as read; the header carries the "mark all read" action.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: AppStrings.notificationsEyebrow,
              title: AppStrings.notifications,
              gradient: const [AppColors.scaffoldDark, AppColors.notificationCard],
              actionIcon: Icons.done_all_rounded,
              actionTooltip: AppStrings.notificationsMarkAllRead,
              onAction: () async {
                final repo =
                    await ref.read(notificationRepoProvider.future);
                await repo.markAllRead();
                ref.invalidate(notificationsProvider);
              },
            ),
            Expanded(
              child: async.when(
                loading: () => const LoadingState(
                  message: AppStrings.notifications,
                ),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
                data: (items) {
                  final list = [...items]
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  if (list.isEmpty) {
                    return const _EmptyInbox();
                  }
                  return _InboxList(
                    items: list,
                    onRead: (n) async {
                      final repo = await ref
                          .read(notificationRepoProvider.future);
                      await repo.markRead(n.id);
                      ref.invalidate(notificationsProvider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: const [
        SizedBox(height: AppSpacing.xxl),
        EmptyState(
          icon: Icons.notifications_none_rounded,
          title: AppStrings.notificationsEmptyTitle,
          message: AppStrings.notificationsEmptyHint,
        ),
      ],
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.items, required this.onRead});
  final List<AppNotification> items;
  final Future<void> Function(AppNotification) onRead;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _NotificationTile(
        item: items[i],
        onRead: () => onRead(items[i]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onRead});
  final AppNotification item;
  final VoidCallback onRead;

  Color get _color => _colorFor(item.kind);
  IconData get _icon => _iconFor(item.kind);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: item.isRead ? null : onRead,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: _icon,
            tint: _color.withValues(alpha: 0.12),
            color: _color,
            size: 52,
            iconSize: 26,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTextStyles.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!item.isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          AppStrings.notificationsUnreadDot,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.message,
                  style: AppTextStyles.bodySecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _KindChip(label: item.kind.bangla, color: _color),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppDate.relativeBangla(item.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(NotificationKind k) {
    switch (k) {
      case NotificationKind.cropCare:
        return AppColors.primary;
      case NotificationKind.weather:
        return AppColors.info;
      case NotificationKind.pest:
        return AppColors.warning;
      case NotificationKind.harvest:
        return AppColors.success;
      case NotificationKind.expense:
        return AppColors.accent;
      case NotificationKind.system:
        return AppColors.textSecondary;
    }
  }

  IconData _iconFor(NotificationKind k) {
    switch (k) {
      case NotificationKind.cropCare:
        return Icons.eco_rounded;
      case NotificationKind.weather:
        return Icons.cloud_outlined;
      case NotificationKind.pest:
        return Icons.bug_report_rounded;
      case NotificationKind.harvest:
        return Icons.agriculture_rounded;
      case NotificationKind.expense:
        return Icons.account_balance_wallet_rounded;
      case NotificationKind.system:
        return Icons.info_outline_rounded;
    }
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
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
