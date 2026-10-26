import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/ai_chat.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/crop.dart';
import '../../data/models/diagnosis.dart';
import '../../data/models/disease.dart';
import '../../data/models/expense.dart';
import '../../data/models/farm.dart';
import '../../data/models/farmer.dart';
import '../../data/models/market_price.dart';
import '../../data/models/recommendation.dart';
import '../../data/models/subscription.dart';
import '../../data/models/weather.dart';
import '../../data/models/profit_estimate.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/crop_repository.dart';
import '../../data/repositories/disease_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/farm_repository.dart';
import '../../data/repositories/farmer_repository.dart';
import '../../data/repositories/local_store.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/repositories/profit_repository.dart';
import '../../data/repositories/user_data_sync.dart';
import '../../data/repositories/tool_plan_repository.dart';
import '../../core/utils/phone_key.dart';
import '../../data/repositories/weather_repository.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/speech_service.dart';
import '../router/app_router.dart';
import '../../core/services/remote_image_storage.dart';

/// Async-initialized dependencies ---------------------------------------------

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

/// Phone-scoped local store. Rebuilds whenever the bdapps auth phone
/// changes (sign-out / sign-in), so reads and shadow-writes land in the
/// correct users/{phone}/... scope automatically.
///
/// This is the canonical provider - every other repo provider should depend
/// on it. It exposes LocalStore (not `AsyncValue<LocalStore>`), matching
/// the existing `localStoreProvider` shape so call-sites that used `ref.watch(localStoreProvider.future)` keep working unchanged.
final localStoreProvider = FutureProvider<LocalStore>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final phone = await ref.watch(authPhoneProvider.future);
  final store = LocalStore(prefs, phone: PhoneKey.fromString(phone));
  // Hydrate this farmer's data from users/{phone}/... before any repository
  // reads the cache (no-op when logged out; falls back to cache offline).
  await UserDataSync.pull(store);
  return store;
});

/// Image uploader for AI crop-doctor scans. Swap implementation here when
/// moving from ImgBB to Firebase Storage - callers don't need to
/// change.
final imageStorageProvider = Provider<RemoteImageStorage>((ref) {
  return ImgbbImageStorage();
});

/// Repositories ---------------------------------------------------------------------

final farmerRepoProvider = FutureProvider<FarmerRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return FarmerRepository(store);
});

final farmRepoProvider = FutureProvider<FarmRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return FarmRepository(store);
});

final cropRepoProvider = FutureProvider<CropRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return CropRepository(store);
});

final diseaseRepoProvider = Provider<DiseaseLibraryRepository>((ref) {
  return DiseaseLibraryRepository();
});

final diagnosisRepoProvider = FutureProvider<DiagnosisRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return DiagnosisRepository(store);
});

final weatherRepoProvider = FutureProvider<WeatherRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return WeatherRepository(store: store);
});

final marketRepoProvider = FutureProvider<MarketRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return MarketRepository(store: store);
});

final expenseRepoProvider = FutureProvider<ExpenseRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return ExpenseRepository(store);
});

final profitRepoProvider = FutureProvider<ProfitRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return ProfitRepository(store);
});

final toolPlanRepoProvider = FutureProvider<ToolPlanRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return ToolPlanRepository(store);
});

final recommendationRepoProvider = Provider<RecommendationRepository>((ref) {
  return RecommendationRepository();
});

final notificationRepoProvider = FutureProvider<NotificationRepository>((
  ref,
) async {
  final store = await ref.watch(localStoreProvider.future);
  return NotificationRepository(store);
});

final subscriptionRepoProvider = FutureProvider<SubscriptionRepository>((
  ref,
) async {
  final store = await ref.watch(localStoreProvider.future);
  return SubscriptionRepository(store);
});

final aiRepoProvider = FutureProvider<AIRepository>((ref) async {
  final diseaseRepo = ref.watch(diseaseRepoProvider);
  final store = await ref.watch(localStoreProvider.future);
  return AIRepository(diseaseRepo, store);
});

/// Services -------------------------------------------------------------------------

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

/// Async data providers --------------------------------------------------------------

/// Returns the saved farmer, or `null` if profile setup hasn't been done.
final currentFarmerProvider = FutureProvider<Farmer?>((ref) async {
  final repo = await ref.watch(farmerRepoProvider.future);
  return repo.currentFarmer();
});

final farmsProvider = FutureProvider<List<Farm>>((ref) async {
  final repo = await ref.watch(farmRepoProvider.future);
  return repo.farms();
});

final cropsProvider = FutureProvider<List<Crop>>((ref) async {
  final repo = await ref.watch(cropRepoProvider.future);
  return repo.crops();
});

final diagnosesProvider = FutureProvider<List<Diagnosis>>((ref) async {
  final repo = await ref.watch(diagnosisRepoProvider.future);
  return repo.all();
});

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repo = await ref.watch(expenseRepoProvider.future);
  return repo.all();
});

final profitRecordsProvider = FutureProvider<List<ProfitEstimate>>((ref) async {
  final repo = await ref.watch(profitRepoProvider.future);
  return repo.all();
});

final notificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final repo = await ref.watch(notificationRepoProvider.future);
  return repo.all();
});

final weatherProvider = FutureProvider<WeatherSnapshot?>((ref) async {
  final repo = await ref.watch(weatherRepoProvider.future);
  final farmer = await ref.watch(currentFarmerProvider.future);
  // Falls back to the farmer's saved district when the user hasn't set a
  // location yet (first-run before profile setup).
  final fallback = farmer?.district ?? 'ঢাকা';
  // GPS-first so the home dashboard reflects the user's *actual* location
  // weather, then district. Errors (no API key, network failure, 401, etc.)
  // propagate as AsyncError so the UI renders ErrorStateView instead of
  // silently substituting bundled demo data.
  try {
    return await repo.currentFromGps(fallbackDistrict: fallback);
  } on WeatherLiveDataUnavailable {
    rethrow;
  } catch (e, st) {
    // Always surface - never fall back to demo data implicitly.
    Error.throwWithStackTrace(e, st);
  }
});

final recommendationsProvider = FutureProvider<List<Recommendation>>((
  ref,
) async {
  final repo = ref.watch(recommendationRepoProvider);
  return repo.all();
});

/// Live stream of market prices: any admin-panel write to Firestore
/// (`market_prices_live`) is pushed to the app immediately, with no cache TTL.
final marketPricesProvider = StreamProvider<List<MarketPrice>>((ref) async* {
  final repo = await ref.watch(marketRepoProvider.future);
  final farmer = await ref.watch(currentFarmerProvider.future);
  yield* repo.watch(farmer?.district ?? 'ঢাকা');
});

final marketFavoritesProvider = FutureProvider<List<MarketPrice>>((ref) async {
  final all = await ref.watch(marketPricesProvider.future);
  return all.where((m) => m.isFavorite).toList(growable: false);
});

final marketCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final all = await ref.watch(marketPricesProvider.future);
  return (all.map((m) => m.category).toSet().toList())..sort();
});

final diseaseLibraryProvider = FutureProvider<List<Disease>>((ref) async {
  final repo = ref.watch(diseaseRepoProvider);
  return repo.all();
});

final currentSubscriptionProvider = FutureProvider<UserSubscription>((
  ref,
) async {
  final repo = await ref.watch(subscriptionRepoProvider.future);
  return repo.current();
});

final aiConversationProvider = FutureProvider<AIConversation>((ref) async {
  final repo = await ref.watch(aiRepoProvider.future);
  return repo.loadConversation();
});

/// Onboarding / first-run gate -------------------------------------------------------

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('onboarding_complete') ?? false;
});

/// Bdapps auth flag (true while the user has a REGISTERED / PENDING
/// subscription cached locally). Re-reads from disk on invalidation.
final authSessionProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('isLoggedIn') ?? false;
});

/// The user's bdapps phone number (empty when not logged in).
final authPhoneProvider = FutureProvider<String>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getString('userPhone') ?? '';
});

/// ---------------------------------------------------------------------------
/// Router (depends on onboardingCompleteProvider + currentFarmerProvider, so
/// it rebuilds when those values change).
/// ---------------------------------------------------------------------------
final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));