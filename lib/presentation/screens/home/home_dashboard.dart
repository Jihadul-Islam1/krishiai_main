import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/profile_photo_service.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/weather.dart';
import '../../providers/app_providers.dart';
import 'farms_carousel.dart';

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  /// Whether the OSM "use my location" flow is currently in flight.
  /// Stored on a StateProvider so any widget can flip the button into a
  /// spinner without rebuilding the whole screen.
  static final _osmBusyProvider = StateProvider<bool>((_) => false);

  Future<void> _useLiveLocation(BuildContext context, WidgetRef ref) async {
    if (ref.read(_osmBusyProvider)) return;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(_osmBusyProvider.notifier).state = true;
    try {
      final repo = await ref.read(weatherRepoProvider.future);
      final farmer = await ref.read(currentFarmerProvider.future);
      // One-shot: GPS → reverse-geocode → real weather for that exact
      // spot. If anything fails (no GPS, OSM down, OWM 401…) we surface
      // the actual reason in the snackbar instead of swallowing it.
      final snap = await repo.currentFromGps(
        fallbackDistrict: farmer?.district ?? 'ঢাকা',
      );
      if (!context.mounted) return;
      // Refresh the live provider so the weather screen stays in sync.
      ref.invalidate(weatherProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '📍 ${snap.location} — ${snap.currentTempC.round()}°C',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('লোকেশন পাওয়া যায়নি: ${_shortError(e)}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      ref.read(_osmBusyProvider.notifier).state = false;
    }
  }

  /// Trim exception text to a short user-friendly line.
  String _shortError(Object e) {
    final s = e.toString();
    if (s.length > 120) return '${s.substring(0, 117)}…';
    return s;
  }

  Future<void> _searchLocation(BuildContext context, WidgetRef ref) async {
    if (ref.read(_osmBusyProvider)) return;
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('স্থান খুঁজুন'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'যেমন: রাজশাহী, সিলেট, Khulna',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('খুঁজুন'),
          ),
        ],
      ),
    );
    if (query == null || query.trim().isEmpty) return;
    ref.read(_osmBusyProvider.notifier).state = true;
    try {
      final repo = await ref.read(weatherRepoProvider.future);
      final hit = await repo.searchLocation(query);
      if (!context.mounted) return;
      if (hit == null) {
        messenger.showSnackBar(
          SnackBar(content: Text('"${query.trim()}" খুঁজে পাওয়া যায়নি')),
        );
        return;
      }
      await repo.currentForCoords(
        lat: hit.lat,
        lon: hit.lon,
        label: hit.label,
      );
      ref.invalidate(weatherProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('📍 ${hit.label}')),
      );
    } finally {
      ref.read(_osmBusyProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final weatherAsync = ref.watch(weatherProvider);
    final farmer = ref.watch(currentFarmerProvider).valueOrNull;
    final farmerName = farmer?.name.trim() ?? '';
    // Live snapshot if available; otherwise we render the same UI with the
    // bundled demo numbers so the layout never jumps.
    final WeatherSnapshot? snap = weatherAsync.valueOrNull;
    // Format helpers derived from the snapshot.
    final today = DateTime.now();
    final todayLabel = _formatBnFullDate(today);

    // Pull 6 days starting from today (so the strip always reads naturally).
    final daily6 = snap != null && snap.daily.isNotEmpty
        ? _padDaily(snap.daily, 6, today)
        : _demoDays(today);
    final currentTemp = snap?.currentTempC.round() ?? 32;
    final condition = snap?.condition ?? WeatherCondition.partlyCloudy;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF5F7F5,
      ), // অ্যাপের নিচের অংশের লাইট ব্যাকগ্রাউন্ড
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ১. টপ হেডার সেকশন (ব্যাকগ্রাউন্ড ইমেজ এবং ওয়েদার কার্ড)
            Stack(
              clipBehavior: Clip.none,
              children: [
                // মেইন ব্যাকগ্রাউন্ড ইমেজ (আগের agro.png ইমেজটিই এখানে ব্যাকগ্রাউন্ড হিসেবে থাকবে)
                Container(
                  height: screenSize.height * 0.42,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/agro.png',
                      ), // আপনার প্রজেক্ট পাথ
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
                // ইমেজের ওপর হালকা ডার্ক ইফেক্ট যাতে টপ টেক্সটগুলো সুন্দর ও স্পষ্ট দেখায়
                Container(
                  height: screenSize.height * 0.42,
                  color: Colors.black.withValues(alpha: 0.25),
                ),

                // হেডার টেক্সট এবং ইউজার প্রোফাইল এরিয়া
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // প্রোফাইল রো (নাম, তারিখ এবং গোল প্রোফাইল পিকচার)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 🔴 Column-টিকে Expanded করা হয়েছে যেন এটি প্রোফাইল পিকচারের বামের খালি জায়গাটুকুর মধ্যে সীমাবদ্ধ থাকে
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmerName.isEmpty
                                        ? 'শুভকামনা'
                                        : 'শুভকামনা, $farmerName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow
                                        .ellipsis, // <--- নাম বেশি বড় হলে শেষে '...' দেখাবে
                                    maxLines:
                                        1, // <--- নাম যেন ভেঙে নিচের লাইনে না যায়
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    todayLabel,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow
                                        .ellipsis, // <--- তারিখ বড় হলেও স্ক্রিন ভাঙবে না
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: 12,
                            ), // 🔴 নাম এবং প্রোফাইল পিকচারের মাঝে একটু নিরাপদ গ্যাপ রাখার জন্য
                            // ইউজার প্রোফাইল পিকচার (সার্কেল এভাটার)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    ProfilePhotoService.change(context, ref),
                                child: UserAvatar(
                                  name: farmerName,
                                  imageUrl: farmer?.profileImagePath,
                                  radius: 24,
                                  backgroundColor: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // মেইন স্লোগান টেক্সট
                        const Text(
                          'চাষ হোক সহজ,\nস্মার্ট এবং টেকসই',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // সার্চ বার এবং লোকেশন বাটন
                        Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(25),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(25),
                                  onTap: () => _searchLocation(context, ref),
                                  child: Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 15),
                                        const Icon(
                                          Icons.search,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        // 🔴 এখানে Expanded যোগ করা হয়েছে যাতে টেক্সটটি সার্চ বারের ভেতরের খালি জায়গাটুকুতেই সীমাবদ্ধ থাকে
                                        Expanded(
                                          child: Text(
                                            weatherAsync
                                                    .valueOrNull
                                                    ?.location ??
                                                'স্থান খুঁজুন',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow
                                                .ellipsis, // এখন এটি সঠিকভাবে কাজ করবে
                                            maxLines:
                                                1, // লেখাটি যেন এক লাইনেই থাকে
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 15,
                                        ), // ডানপাশে একটু খালি জায়গা রাখার জন্য
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // লোকেশন বাটন — GPS + OpenStreetMap দিয়ে
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _useLiveLocation(context, ref),
                                child: SizedBox(
                                  height: 50,
                                  width: 50,
                                  child: Center(
                                    child: Consumer(
                                      builder: (ctx, ref, _) {
                                        final busy = ref.watch(
                                          _osmBusyProvider,
                                        );
                                        if (busy) {
                                          return const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.black87,
                                            ),
                                          );
                                        }
                                        return const Icon(
                                          Icons.location_on_outlined,
                                          color: Colors.black87,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )

                      ],
                    ),
                  ),
                ),

                // ২. ওয়েদার ওভারল্যাপ কার্ড (গ্লাস মরফিজম শেড)
                Positioned(
                  top: screenSize.height * 0.32,
                  left: 20,
                  right: 20,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => context.push('/weather'),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E3B2E).withValues(
                            alpha: 0.85,
                          ), // স্ক্রিনশটের ডার্ক শেড কালার
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // সাপ্তাহিক দিনগুলোর হরিজন্টাল লিস্ট
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (var i = 0; i < daily6.length; i++)
                                  _buildWeatherDayFromDaily(daily6[i], i == 0),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              todayLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$currentTemp°C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      _iconFor(condition),
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _conditionBn(condition),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.wb_cloudy,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'আবহাওয়া',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 14,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'ফসলের জন্য উপযুক্ত',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ওয়েদার কার্ডের নিচের স্পেসিং অ্যাডজাস্টমেন্ট
            SizedBox(height: screenSize.height * 0.18),

            // ৩. ক্রপ ফিল্টার ক্যাটাগরি চিপস (গম, আঙুর, আলু, ধান)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCropChip(
                      'গম',
                      const Color(0xFFFF9800),
                      true,
                      onTap: () => context.push('/farm/crops'),
                    ), // গম সিলেক্টেড (অরেঞ্জ কালার)
                    const SizedBox(width: 10),
                    _buildCropChip(
                      'আঙুর',
                      Colors.white,
                      false,
                      onTap: () => context.push('/farm/crops'),
                    ),
                    const SizedBox(width: 10),
                    _buildCropChip(
                      'আলু',
                      Colors.white,
                      false,
                      onTap: () => context.push('/farm/crops'),
                    ),
                    const SizedBox(width: 10),
                    _buildCropChip(
                      'ধান',
                      Colors.white,
                      false,
                      onTap: () => context.push('/farm/crops'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ৪. "আমার জমি" টাইটেল রো
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'আমার জমি',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/farm'),
                    child: const Text(
                      'সব দেখুন >',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ৫. আমার জমি — ফার্মারের সব জমি (ছবিসহ, স্ক্রল করা যায়)
            const FarmsCarousel(),
            const SizedBox(height: 0),
            // ৬. "দ্রুত টুলস" — কোডে থাকা বাকি স্ক্রিনগুলোতে যাওয়ার শর্টকাট গ্রিড
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.fromARGB(255, 137, 146, 137), Color.fromARGB(255, 9, 9, 9)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'দ্রুত টুলস',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 0),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _buildToolCard(
                          title: 'AI ক্রপ ডাক্তার',
                          subtitle: 'রোগ শনাক্ত',
                          icon: Icons.camera_alt,
                          onTap: () => context.push('/ai/scan'),
                        ),
                        _buildToolCard(
                          title: 'AI সহকারী',
                          subtitle: 'প্রশ্ন করুন',
                          icon: Icons.smart_toy,
                          onTap: () => context.go('/ai'),
                        ),
                        _buildToolCard(
                          title: 'আবহাওয়া',
                          subtitle: '৭ দিনের পূর্বাভাস',
                          icon: Icons.wb_sunny,
                          onTap: () => context.push('/weather'),
                        ),
                        _buildToolCard(
                          title: 'বাজার দর',
                          subtitle: 'আজকের দাম',
                          icon: Icons.storefront,
                          onTap: () => context.go('/market'),
                        ),
                        _buildToolCard(
                          title: 'রোগ লাইব্রেরি',
                          subtitle: 'চিকিৎসা গাইড',
                          icon: Icons.local_library,
                          onTap: () => context.push('/library'),
                        ),
                        _buildToolCard(
                          title: 'খরচ ট্র্যাকার',
                          subtitle: 'খাতা-কাটা হিসাব',
                          icon: Icons.account_balance_wallet,
                          onTap: () => context.push('/expenses'),
                        ),
                        _buildToolCard(
                          title: 'লাভ গণনা',
                          subtitle: 'ফসলের মুনাফা',
                          icon: Icons.calculate,
                          onTap: () => context.push('/profit'),
                        ),
                        _buildToolCard(
                          title: 'বিশ্লেষণ',
                          subtitle: 'চার্ট ও রিপোর্ট',
                          icon: Icons.bar_chart,
                          onTap: () => context.push('/analytics'),
                        ),
                        _buildToolCard(
                          title: 'সেচ পরামর্শ',
                          subtitle: 'কখন, কতটুকু',
                          icon: Icons.water_drop,
                          onTap: () => context.push('/irrigation'),
                        ),
                        _buildToolCard(
                          title: 'সার পরামর্শ',
                          subtitle: 'ডোজ নির্দেশনা',
                          icon: Icons.grass,
                          onTap: () => context.push('/fertilizer'),
                        ),
                        _buildToolCard(
                          title: 'স্ক্যান ইতিহাস',
                          subtitle: 'আগের রিপোর্ট',
                          icon: Icons.history,
                          onTap: () => context.push('/ai/history'),
                        ),
                        _buildToolCard(
                          title: 'নোটিফিকেশন',
                          subtitle: 'আপডেট ও অ্যালার্ট',
                          icon: Icons.notifications,
                          onTap: () => context.push('/notifications'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // -------- Real-data helpers (OpenWeatherMap) ------------------------------

  /// Converts digits to Bangla equivalent (0–9).
  String _bangleDigit(int n) {
    const map = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    final s = n.toString();
    final b = StringBuffer();
    for (final c in s.split('')) {
      b.write(c == '-' ? '-' : map[int.parse(c)]);
    }
    return b.toString();
  }

  String _bnMonth(int m) {
    const months = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
      'মার্চ',
      'এপ্রিল',
      'মে',
      'জুন',
      'জুলাই',
      'আগস্ট',
      'সেপ্টেম্বর',
      'অক্টোবর',
      'নভেম্বর',
      'ডিসেম্বর',
    ];
    return months[m - 1];
  }

  /// Render the full Bangla date (e.g. "সোমবার, ০২ সেপ্টেম্বর ২০২৫").
  String _formatBnFullDate(DateTime d) {
    const days = [
      'সোমবার',
      'মঙ্গলবার',
      'বুধবার',
      'বৃহস্পতিবার',
      'শুক্রবার',
      'শনিবার',
      'রবিবার',
    ];
    return '${days[d.weekday - 1]}, ${_bangleDigit(d.day)} ${_bnMonth(d.month)} ${_bangleDigit(d.year)}';
  }

  /// Pads the OpenWeatherMap `daily` list with synthetic placeholders so the
  /// 6-cell strip on the home dashboard always has exactly 6 entries.
  List<DailyForecast> _padDaily(
    List<DailyForecast> src,
    int n,
    DateTime today,
  ) {
    final out = <DailyForecast>[];
    for (var i = 0; i < n; i++) {
      if (i < src.length) {
        out.add(src[i]);
      } else {
        out.add(
          DailyForecast(
            date: DateTime(today.year, today.month, today.day + i),
            maxTempC: 32,
            minTempC: 24,
            condition: WeatherCondition.partlyCloudy,
            rainProbability: 0.2,
            humidity: 0.7,
            windKmh: 10,
          ),
        );
      }
    }
    return out;
  }

  /// Hardcoded 6-day demo strip used while the real API call is in-flight
  /// or when the user hasn't supplied an API key.
  List<DailyForecast> _demoDays(DateTime today) {
    return List.generate(6, (i) {
      final d = DateTime(today.year, today.month, today.day + i);
      return DailyForecast(
        date: d,
        maxTempC: (28 + i).toDouble(),
        minTempC: (22 + i).toDouble(),
        condition:
            i == 2 ? WeatherCondition.sunny : WeatherCondition.partlyCloudy,
        rainProbability: i == 4 ? 0.7 : 0.2,
        humidity: 0.7,
        windKmh: 12,
      );
    });
  }

  IconData _iconFor(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
      case WeatherCondition.partlyCloudy:
        return Icons.wb_sunny_outlined;
      case WeatherCondition.cloudy:
        return Icons.wb_cloudy_outlined;
      case WeatherCondition.rainy:
        return Icons.cloudy_snowing;
      case WeatherCondition.stormy:
        return Icons.cloud_queue;
      case WeatherCondition.foggy:
        return Icons.wb_cloudy_outlined;
    }
  }

  String _conditionBn(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
        return 'উজ্জ্বল রোদ';
      case WeatherCondition.partlyCloudy:
        return 'রোদ-মেঘলা';
      case WeatherCondition.cloudy:
        return 'মেঘলা';
      case WeatherCondition.rainy:
        return 'বৃষ্টি';
      case WeatherCondition.stormy:
        return 'ঝড়';
      case WeatherCondition.foggy:
        return 'কুয়াশা';
    }
  }

  // সপ্তাহের দিনগুলোর কাস্টম মেথড উইজেট — same look as before, fed by
  // `DailyForecast` (real or demo).
  Widget _buildWeatherDayFromDaily(DailyForecast day, bool isSelected) {
    final tempText = '${day.maxTempC.round()}°';
    final icon = _iconFor(day.condition);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFF9800)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _bangleDigit(day.date.day),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Icon(icon, color: isSelected ? Colors.white : Colors.amber, size: 18),
          const SizedBox(height: 6),
          Text(
            tempText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ৩. ক্রপ চিপ — সিলেক্টেড হলে কমলা ব্যাকগ্রাউন্ড, অন্যথায় সাদা।
  Widget _buildCropChip(
    String label,
    Color bg,
    bool selected, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // দ্রুত টুলস — ২-কলাম গ্রিডে ব্যবহৃত কার্ড (টাইটেল + সাবটাইটেল + আইকন)।
  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFFF9800), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
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

// Alias used by lib/main.dart - the original agro.png dashboard.
typedef HomeScreen = HomeDashboard;
