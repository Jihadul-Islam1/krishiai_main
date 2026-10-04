import 'package:flutter/foundation.dart';

import '../../core/services/fs_paths.dart';
import '../models/subscription.dart';
import 'local_store.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._store);

  static const _key = 'subscription';
  final LocalStore _store;

  List<SubscriptionPlan> availablePlans() {
    return const [
      SubscriptionPlan(
        id: 'free',
        tier: SubscriptionTier.free,
        title: 'ফ্রি',
        priceLabel: '৳ 0',
        monthlyPrice: 0,
        yearlyPrice: 0,
        features: [
          'দৈনিক ১টি AI রোগ শনাক্তকরণ',
          'সাধারণ আবহাওয়া',
          'মূল বাজারদর',
        ],
      ),
      SubscriptionPlan(
        id: 'premium-monthly',
        tier: SubscriptionTier.premium,
        title: 'প্রিমিয়াম (মাসিক)',
        priceLabel: '৳ 299 / মাস',
        monthlyPrice: 299,
        yearlyPrice: 299,
        features: [
          'আনলিমিটেড AI রোগ শনাক্তকরণ',
          'AI সহকারী চ্যাট',
          'বিস্তারিত আবহাওয়া + ৭ দিনের পূর্বাভাস',
          'বাজারদর বিশ্লেষণ',
          'লাভ/ক্ষতি হিসাব',
          'বিশেষজ্ঞ পরামর্শ',
        ],
      ),
      SubscriptionPlan(
        id: 'premium-yearly',
        tier: SubscriptionTier.premium,
        title: 'প্রিমিয়াম (বার্ষিক)',
        priceLabel: '৳ 2988 / বছর',
        monthlyPrice: 249,
        yearlyPrice: 2988,
        features: [
          'সব প্রিমিয়াম সুবিধা',
          'বার্ষিক ১৬% সাশ্রয়',
          'অগ্রাধিকার সহায়তা',
        ],
      ),
    ];
  }

  Future<UserSubscription> current() async {
    final raw = _store.readJson(_key);
    if (raw is Map<String, dynamic>) {
      return UserSubscription.fromJson(raw);
    }

    final phone = _store.phoneKey;
    if (phone != null) {
      try {
        final snap = await FsPaths.subscription(phone).get();
        final data = snap.data();
        if (data != null && data.isNotEmpty) {
          await _store.writeJson(_key, data);
          return UserSubscription.fromJson(data);
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[SubscriptionRepository] remote fetch failed: $e\n$st',
          );
        }
      }
    }
    return UserSubscription.free();
  }

  Future<void> update(UserSubscription sub) async {
    await _store.writeJson(_key, sub.toJson());

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.subscription(phone).set(sub.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SubscriptionRepository] shadow write failed: $e\n$st',
        );
      }
    }
  }

  Future<void> setPremium({required bool active, int days = 30}) async {
    final now = DateTime.now();
    await update(
      UserSubscription(
        tier: active ? SubscriptionTier.premium : SubscriptionTier.free,
        status: active ? SubscriptionStatus.active : SubscriptionStatus.none,
        activatedAt: active ? now : null,
        expiresAt: active ? now.add(Duration(days: days)) : null,
        planId: active ? 'premium-monthly' : 'free',
        lastUpdated: now,
      ),
    );
  }
}
