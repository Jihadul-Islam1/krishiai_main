import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/firestore_service.dart';
import 'firebase_options.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/onboarding/marketing_onboarding_screen.dart' show MarketingOnboardingScreen;

const String _kOnboardingDoneKey = 'krishiai.onboardingDone';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1) .env first - ImgBB + OpenWeatherMap keys must be available
  //    synchronously before any service is constructed.
  await dotenv.load(fileName: '.env', mergeWith: <String, String>{});
  // 2) Firebase (Firestore) before any repository is touched.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirestoreService.boot();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: KrishiAI()));
}

class KrishiAI extends ConsumerWidget {
  const KrishiAI({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Krishi AI',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('bn'), Locale('en')],
      locale: const Locale('bn'),
      home: const _AppRoot(),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF2E7D32);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        secondary: const Color(0xFFFF9800),
        surface: const Color(0xFFF5F7F5),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F5),
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}

/// Decides which screen to show on cold start.
///
/// - First launch (no flag in SharedPreferences): show the marketing
///   onboarding screen from `start.dart`.
/// - Subsequent launches: jump straight into the Riverpod/GoRouter app.
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  Future<void> _loadFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _onboardingDone = prefs.getBool(_kOnboardingDoneKey) ?? false);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDoneKey, true);
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_onboardingDone == false) {
      return MarketingOnboardingScreen(
        onGetStarted: _completeOnboarding,
      );
    }
    return const _AuthenticatedApp();
  }
}

/// Wraps the Riverpod/GoRouter app (5-tab shell + every other screen).
class _AuthenticatedApp extends ConsumerWidget {
  const _AuthenticatedApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Krishi AI',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}