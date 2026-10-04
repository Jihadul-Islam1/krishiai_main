import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/ai/ai_assistant_screen.dart';
import '../screens/ai/crop_doctor_screen.dart';
import '../screens/ai/scan_result_screen.dart';
import '../screens/ai/scan_history_screen.dart';
import '../screens/farm/add_crop_screen.dart';
import '../screens/farm/add_farm_screen.dart';
import '../screens/farm/crop_detail_screen.dart';
import '../screens/farm/farm_detail_screen.dart';
import '../screens/farm/my_crops_screen.dart';
import '../screens/farm/my_farm_screen.dart';
import '../screens/finance/expense_tracker_screen.dart';
import '../screens/finance/profit_calculator_screen.dart';
import '../screens/finance/analytics_screen.dart';
import '../screens/home/home_dashboard.dart';
import '../screens/auth/login_screen.dart';
import '../screens/library/disease_library_screen.dart';
import '../screens/library/disease_detail_screen.dart';
import '../screens/market/market_screen.dart';
import '../screens/market/market_detail_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/permissions_screen.dart';
import '../screens/onboarding/profile_setup_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/help_screen.dart';
import '../screens/settings/privacy_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import '../screens/tools/fertilizer_screen.dart';
import '../screens/tools/irrigation_screen.dart';
import '../screens/weather/weather_screen.dart';
import '../widgets/main_shell.dart';
import '../providers/app_providers.dart';
import '../../data/models/diagnosis.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final onboard = ref.read(onboardingCompleteProvider);
      final auth = ref.read(authSessionProvider);
      final loc = state.matchedLocation;

      if (onboard.isLoading || onboard.hasError || auth.isLoading) {
        return null;
      }
      final done = onboard.valueOrNull ?? false;
      final loggedIn = auth.valueOrNull ?? false;

      if (loc == '/splash') {
        if (!done) return '/onboarding';
        return loggedIn ? '/home' : '/login';
      }
      const publicRoutes = {
        '/onboarding',
        '/profile-setup',
        '/permissions',
        '/login',
      };
      if (!done) {
        // Profile setup still pending — keep the user inside onboarding.
        if (publicRoutes.contains(loc)) return null;
        return '/onboarding';
      }
      if (!loggedIn) {
        // Onboarding done but bdapps auth missing → force login.
        if (loc == '/login') return null;
        return '/login';
      }
      if (loc == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/profile-setup',
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/permissions',
        builder: (_, _) => const PermissionsScreen(),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeDashboard()),
          GoRoute(path: '/farm', builder: (_, _) => const MyFarmScreen()),
          GoRoute(path: '/ai', builder: (_, _) => const AIAssistantScreen()),
          GoRoute(path: '/market', builder: (_, _) => const MarketScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/farm/crops', builder: (_, _) => const MyCropsScreen()),
      GoRoute(
        path: '/farm/crops/:id',
        builder: (_, state) =>
            MyCropsScreen(farmId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/farm/:id',
        builder: (_, state) =>
            FarmDetailScreen(farmId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/farm/crop/:id',
        builder: (_, state) =>
            CropDetailScreen(cropId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/farm/add', builder: (_, _) => const AddFarmScreen()),
      GoRoute(
        path: '/farm/add-crop',
        builder: (_, state) {
          final extra = state.extra;
          final farmId = extra is Map ? extra['farmId'] as String? : null;
          return AddCropScreen(farmId: farmId);
        },
      ),
      GoRoute(path: '/ai/scan', builder: (_, _) => const CropDoctorScreen()),
      GoRoute(
        path: '/ai/history',
        builder: (_, _) => const ScanHistoryScreen(),
      ),
      GoRoute(
        path: '/ai/scan/result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ScanResultScreen(
            diagnosis: extra['diagnosis'] as Diagnosis,
            imagePath: extra['imagePath'] as String?,
          );
        },
      ),
      GoRoute(path: '/weather', builder: (_, _) => const WeatherScreen()),
      GoRoute(
        path: '/library',
        builder: (_, _) => const DiseaseLibraryScreen(),
      ),
      GoRoute(
        path: '/library/:id',
        builder: (_, state) =>
            DiseaseDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/market/:id',
        builder: (_, state) =>
            MarketDetailScreen(priceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/expenses',
        builder: (_, _) => const ExpenseTrackerScreen(),
      ),
      GoRoute(
        path: '/profit',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ProfitCalculatorScreen(),
      ),
      GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsScreen()),
      GoRoute(path: '/irrigation', builder: (_, _) => const IrrigationScreen()),
      GoRoute(path: '/fertilizer', builder: (_, _) => const FertilizerScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/subscription',
        builder: (_, _) => const SubscriptionScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
    ],
  );
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(onboardingCompleteProvider, (_, _) => notifyListeners());
    ref.listen(currentFarmerProvider, (_, _) => notifyListeners());
    ref.listen(authSessionProvider, (_, _) => notifyListeners());
  }
}
