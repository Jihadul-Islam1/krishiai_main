import 'package:flutter/material.dart';

/// Marketing splash shown on first launch — the "Smart Solutions, Modern
/// Farmers" hero with the `assets/agro.png` background. Lives with the
/// other onboarding screens in this folder.
///
/// `main.dart` wires `onGetStarted` to flip the `krishiai.onboardingDone`
/// SharedPreferences flag and swap into the authenticated Riverpod/GoRouter
/// shell.
class MarketingOnboardingScreen extends StatelessWidget {
  const MarketingOnboardingScreen({super.key, this.onGetStarted});

  /// Called when the user taps "Get Started". `main.dart` supplies the
  /// real callback; standalone runs (see `lib/start.dart`) fall back to
  /// a safe pop.
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Original background image layer
          Positioned.fill(
            child: Image.asset(
              'assets/agro.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, -0.15),
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF1E3A27),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 64,
                      color: Colors.white24,
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. White fading overlay (top section)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenSize.height * 0.52,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // 3. Bottom dark shadow overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: screenSize.height * 0.18,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),

          // 4. Main UI content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // Leaf logo
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Color(0xFF2E7D32),
                      size: 26,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title text
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: screenSize.width * 0.09,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Smart ',
                          style: TextStyle(color: Color(0xFF2E7D32)),
                        ),
                        TextSpan(
                          text: 'Solutions\n',
                          style: TextStyle(color: Color(0xFF212121)),
                        ),
                        TextSpan(
                          text: 'Modern ',
                          style: TextStyle(color: Color(0xFF212121)),
                        ),
                        TextSpan(
                          text: 'Farmers',
                          style: TextStyle(color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  SizedBox(
                    width: screenSize.width * 0.85,
                    child: const Text(
                      'Empowering farmers with smart tools for better yields and decisions.',
                      style: TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 5. Get Started button
                  Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A7A3E),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: () {
                          if (onGetStarted != null) {
                            onGetStarted!();
                            return;
                          }
                          Navigator.of(context).maybePop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  color: Color(0xFF2A7A3E),
                                  size: 24,
                                ),
                              ),
                              const Expanded(
                                child: Center(
                                  child: Text(
                                    'Get Started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    3,
                                    (index) => Icon(
                                      Icons.arrow_forward_ios,
                                      size: 11,
                                      color: Colors.white
                                          .withValues(alpha: (index + 1) * 0.3),
                                    ),
                                  ).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
