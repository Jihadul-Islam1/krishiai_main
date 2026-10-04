import 'package:flutter/foundation.dart';

enum SubscriptionTier { free, premium }

enum SubscriptionStatus { active, expired, pending, failed, none }

@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.tier,
    required this.title,
    required this.priceLabel,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
  });

  final String id;
  final SubscriptionTier tier;
  final String title;
  final String priceLabel;
  final double monthlyPrice;
  final double yearlyPrice;
  final List<String> features;
}

@immutable
class UserSubscription {
  const UserSubscription({
    required this.tier,
    required this.status,
    this.planId,
    this.activatedAt,
    this.expiresAt,
    this.expiry,
    this.lastUpdated,
    this.transactionId,
  });

  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final String? planId;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final DateTime? expiry;
  final DateTime? lastUpdated;
  final String? transactionId;

  bool get isPremium =>
      tier == SubscriptionTier.premium && status == SubscriptionStatus.active;

  factory UserSubscription.free() => const UserSubscription(
    tier: SubscriptionTier.free,
    status: SubscriptionStatus.none,
    planId: 'free',
  );

  UserSubscription copyWith({
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    String? planId,
    DateTime? activatedAt,
    DateTime? expiresAt,
    DateTime? expiry,
    DateTime? lastUpdated,
    String? transactionId,
  }) {
    return UserSubscription(
      tier: tier ?? this.tier,
      status: status ?? this.status,
      planId: planId ?? this.planId,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      expiry: expiry ?? this.expiry,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      transactionId: transactionId ?? this.transactionId,
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': tier.name,
    'status': status.name,
    'planId': planId,
    'activatedAt': activatedAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'expiry': (expiresAt ?? expiry)?.toIso8601String(),
    'lastUpdated': (lastUpdated ?? DateTime.now()).toIso8601String(),
    'transactionId': transactionId,
  };

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      UserSubscription(
        tier: SubscriptionTier.values.firstWhere(
          (e) => e.name == (json['tier'] as String? ?? 'free'),
          orElse: () => SubscriptionTier.free,
        ),
        status: SubscriptionStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? 'none'),
          orElse: () => SubscriptionStatus.none,
        ),
        planId: json['planId'] as String?,
        activatedAt: json['activatedAt'] != null
            ? DateTime.parse(json['activatedAt'] as String)
            : null,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : (json['expiry'] != null
                  ? DateTime.parse(json['expiry'] as String)
                  : null),
        expiry: json['expiry'] != null
            ? DateTime.parse(json['expiry'] as String)
            : null,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : null,
        transactionId: json['transactionId'] as String?,
      );
}
