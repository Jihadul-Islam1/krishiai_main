import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_providers.dart';

/// Base URL of the bdapps PHP backend. All subscription / OTP endpoints
/// (send_otp, verify_otp, check_subscription, unsubscribe) live under
/// this prefix. UPDATE THE PATH to your own deployment.
const String _kBaseUrl = 'https://bdappsdigitalapps.com/NADB26029KrishiAI/';

/// SharedPreferences keys for auth state.
const String _kIsLoggedIn = 'isLoggedIn';
const String _kUserPhone = 'userPhone';

/// Robi/Circel BDapps whitelisted prefixes (016 / 018).
bool _isSupportedNumber(String phone) {
  return RegExp(r'^01(?:6|8)\d{8}$').hasMatch(phone);
}

/// Whitelisted test phone numbers that bypass bdapps OTP (for web preview / developer testing).
const Set<String> _kTestNumbers = {'01800000000', '01600000000', '01812345678'};

/// TEMPORARY: shows an extra "test login" box (any BD number + OTP 123456)
/// that skips the bdapps server. Set to false (or delete the box) once the
/// bdapps backend is reachable again - it works in release APKs too.
const bool _kEnableTestLogin = true;
const String _kTestOtp = '123456';

/// bdapps `app_id` for the Krishi AI subscription product. Must match
/// the value registered on https://developer.bdapps.io for app
/// NADB26029KrishiAI. UPDATE THIS if you redeploy under a different id.
const String _kAppId = 'NADB26029KrishiAI';

/// Headers every POST to the bdapps PHP backend must include.
/// Without `Content-Type: application/x-www-form-urlencoded` some PHP
/// deployments silently drop the body and the OTP is never sent.
const Map<String, String> _kFormHeaders = {
  'Content-Type': 'application/x-www-form-urlencoded',
  'Accept': 'application/json',
};

/// Hits `check_subscription.php`. Returns true when the user is REGISTERED
/// or INITIAL CHARGING PENDING — both states grant login access.
Future<bool> _isUserSubscribedOrPending(String phone) async {
  try {
    final response = await http
        .post(
          Uri.parse('${_kBaseUrl}check_subscription.php'),
          headers: _kFormHeaders,
          body: {'user_mobile': phone, 'app_id': _kAppId},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return false;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return false;

    final status =
        decoded['subscriptionStatus']?.toString().trim().toUpperCase() ?? '';
    return status == 'REGISTERED' || status == 'INITIAL CHARGING PENDING';
  } catch (_) {
    return false;
  }
}

/// Polls `check_subscription.php` until REGISTERED / INITIAL CHARGING
/// PENDING is reported or `maxAttempts` is exhausted.
Future<bool> _waitForSubscriptionSync(
  String phone, {
  int maxAttempts = 5,
  Duration delay = const Duration(seconds: 1),
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    await Future.delayed(delay);
    if (await _isUserSubscribedOrPending(phone)) {
      return true;
    }
  }
  return false;
}

/// Persists the auth state to local storage. Returns when both writes
/// are flushed.
Future<void> _persistAuth(String phone) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kIsLoggedIn, true);
  await prefs.setString(_kUserPhone, phone);
}

/// Clears auth state.
Future<void> _clearAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kIsLoggedIn, false);
  await prefs.remove(_kUserPhone);
  // Cached data is keyed by phone number and the farmer's data stays in
  // Firestore, so logging out only drops the session; the next login
  // (this or another number) re-hydrates its own data.
}

/// Invalidates the auth provider(s) so GoRouter re-evaluates the
/// redirect. Pass a [WidgetRef] obtained from a `Consumer*` widget.
void _invalidateAuth(WidgetRef ref) {
  ref.invalidate(authSessionProvider);
  ref.invalidate(authPhoneProvider);
  // localStoreProvider watches authPhoneProvider, so it will rebuild on
  // its own - we invalidate it explicitly so consumers see the loading
  // gap immediately instead of the previous user's data while we wait.
  ref.invalidate(localStoreProvider);
}

/// Reads the first non-empty string in `keys` from the map.
String _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}

/// ───────────────────────────────────────────────────────────────────────────
/// Login page (phone entry → subscribes the user via bdapps OTP).
/// ───────────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _loginDirectly(String phone) async {
    setState(() => _isLoading = true);
    try {
      _showSuccess(
        kIsWeb ? 'ওয়েব টেস্ট মোড: লগইন সফল!' : 'টেস্ট মোড: লগইন সফল!',
      );
      await Future.delayed(const Duration(milliseconds: 600));
      await _persistAuth(phone);
      _invalidateAuth(ref);
      if (!mounted) return;
      _goHome();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final TextEditingController _testPhoneController = TextEditingController();
  final TextEditingController _testOtpController = TextEditingController();

  Future<void> _onTestLogin() async {
    final phone = _testPhoneController.text.trim();
    final otp = _testOtpController.text.trim();
    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(phone)) {
      _showError('সঠিক ১১ ডিজিটের নম্বর দিন (01XXXXXXXXX)');
      return;
    }
    if (otp != _kTestOtp) {
      _showError('টেস্ট OTP ভুল (123456 দিন)');
      return;
    }
    await _loginDirectly(phone);
  }

  Future<void> _onContinue() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      if (kIsWeb || kDebugMode) {
        await _loginDirectly('01812345678');
        return;
      }
      _showError('মোবাইল নম্বর দিন');
      return;
    }
    if (!_isSupportedNumber(phone) &&
        !(kDebugMode && _kTestNumbers.contains(phone))) {
      _showError('সঠিক Robi/Circel নম্বর দিন (016/018)');
      return;
    }

    // Bypass for web browser (prevents CORS 'Failed to fetch') or developer debug testing
    if (kIsWeb || (kDebugMode && _kTestNumbers.contains(phone))) {
      await _loginDirectly(phone);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) Already subscribed? Skip OTP.
      final isSubscribed = await _isUserSubscribedOrPending(phone);
      if (isSubscribed) {
        _showSuccess('স্বাগতম! লগইন হচ্ছে...');
        await Future.delayed(const Duration(milliseconds: 800));
        await _persistAuth(phone);
        _invalidateAuth(ref);
        if (!mounted) return;
        _goHome();
        return;
      }

      // 2) Send OTP request.
      final otpResponse = await http
          .post(
            Uri.parse('${_kBaseUrl}send_otp.php'),
            headers: _kFormHeaders,
            body: {'user_mobile': phone, 'msisdn': phone, 'app_id': _kAppId},
          )
          .timeout(const Duration(seconds: 15));

      if (otpResponse.statusCode != 200) {
        // e.g. 403 "Access denied." from the PHP host: not JSON, so report
        // the real cause instead of a generic format error.
        _showError(
          'সার্ভার অনুরোধ গ্রহণ করেনি (HTTP ${otpResponse.statusCode})। '
          'bdapps সার্ভারের সেটিংস/অ্যাক্সেস পরীক্ষা করুন।',
        );
        return;
      }

      final otpData = jsonDecode(otpResponse.body);
      if (otpData is! Map<String, dynamic>) {
        _showError('সার্ভার থেকে ভুল তথ্য এসেছে');
        return;
      }

      final success = otpData['success'] == true;
      final referenceNo = _readString(otpData, [
        'referenceNo',
        'reference_no',
        'sessionId',
        'session_id',
        'requestId',
        'request_id',
      ]);
      final message = otpData['message']?.toString() ?? '';
      final statusDetail = otpData['statusDetail']?.toString() ?? '';
      final statusCode = otpData['statusCode']?.toString().trim() ?? '';
      final effectiveSuccess =
          success || statusCode == 'S1000' || referenceNo.isNotEmpty;

      if (effectiveSuccess && referenceNo.isNotEmpty) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerifyPage(
              phone: phone,
              referenceNo: referenceNo,
              onVerified: () {
                if (!mounted) return;
                _goHome();
              },
            ),
          ),
        );
      } else if (statusCode == 'E1351' ||
          message.toLowerCase().contains('already registered')) {
        // Server says the user is already in the system. Re-check with
        // polling — billing may still be ticking.
        final subscribed = await _waitForSubscriptionSync(phone);
        if (!mounted) return;

        if (!subscribed) {
          _showError(
            'সাবস্ক্রিপশন এখনো সক্রিয় হয়নি। কিছুক্ষণ পর আবার চেষ্টা করুন।',
          );
          return;
        }

        _showSuccess('ইতিমধ্যে রেজিস্টার করা! লগইন হচ্ছে...');
        await Future.delayed(const Duration(milliseconds: 800));
        await _persistAuth(phone);
        _invalidateAuth(ref);
        if (!mounted) return;
        _goHome();
      } else {
        final errorMsg = message.isNotEmpty
            ? message
            : (statusDetail.isNotEmpty ? statusDetail : 'OTP পাঠানো যায়নি');
        _showError(errorMsg);
      }
    } on TimeoutException {
      _showError('সার্ভারে দেরি হচ্ছে। আবার চেষ্টা করুন।');
    } on SocketException {
      _showError('ইন্টারনেট সংযোগ নেই। Wi-Fi/মোবাইল ডেটা চেক করুন।');
    } on http.ClientException catch (e) {
      if (kIsWeb) {
        _showError(
          'ব্রাউজারে CORS সীমাবদ্ধতার কারণে সংযোগ ব্যর্থ। অনুগ্রহ করে "ওয়েব টেস্ট লগইন" ব্যবহার করুন।',
        );
      } else {
        _showError('সার্ভারে যোগাযোগ ব্যর্থ: ${e.message}');
      }
    } on FormatException {
      _showError('সার্ভার থেকে ভুল উত্তর এসেছে। আবার চেষ্টা করুন।');
    } catch (e) {
      _showError('নেটওয়ার্ক সমস্যা: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    // Replace the entire stack with home so back-button doesn't
    // return to login.
    context.go('/home');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _testPhoneController.dispose();
    _testOtpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App icon — falls back to a green leaf if the asset
                // (assets/app_icon.png) isn't shipped.
                Image.asset(
                  'assets/agro.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      size: 64,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Krishi AI',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '২.৭৮ টাকা/দিন (ভ্যাট, এসডি ও এসসি সহ)। শুধুমাত্র Robi ও Circel গ্রাহকদের জন্য।',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'মোবাইল নম্বর',
                    hintText: '01XXXXXXXXX',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: _onContinue,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'পরবর্তী',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                if (kIsWeb || kDebugMode) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _loginDirectly(
                            _phoneController.text.trim().isNotEmpty &&
                                    (_isSupportedNumber(
                                          _phoneController.text.trim(),
                                        ) ||
                                        _kTestNumbers.contains(
                                          _phoneController.text.trim(),
                                        ))
                                ? _phoneController.text.trim()
                                : '01812345678',
                          ),
                    icon: const Icon(Icons.bolt_rounded, color: Colors.orange),
                    label: const Text(
                      'ওয়েব টেস্ট লগইন (সরাসরি প্রবেশ)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade800,
                      side: BorderSide(
                        color: Colors.green.shade400,
                        width: 1.5,
                      ),
                      backgroundColor: Colors.green.shade50.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 ব্রাউজারে CORS সীমাবদ্ধতা এড়াতে সরাসরি প্রবেশ ব্যবহার করুন।',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (_kEnableTestLogin) ...[
                  const SizedBox(height: 28),
                  _buildTestLoginBox(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Temporary test box - see [_kEnableTestLogin].
  Widget _buildTestLoginBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.science_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                'টেস্ট লগইন (সাময়িক)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'যেকোনো নম্বর + OTP $_kTestOtp। bdapps সার্ভার ব্যবহার হয় না।',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testPhoneController,
            keyboardType: TextInputType.phone,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'টেস্ট মোবাইল নম্বর',
              hintText: '01XXXXXXXXX',
              prefixIcon: const Icon(Icons.phone_android_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _testOtpController,
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'OTP',
              hintText: _kTestOtp,
              counterText: '',
              prefixIcon: const Icon(Icons.password_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoading ? null : _onTestLogin,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('টেস্ট লগইন'),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// OTP verification page. Pops back to login on failure; calls
/// `onVerified` after [persistAuth] so login page can swap to home.
/// ───────────────────────────────────────────────────────────────────────────

class OtpVerifyPage extends ConsumerStatefulWidget {
  const OtpVerifyPage({
    super.key,
    required this.phone,
    required this.referenceNo,
    required this.onVerified,
  });

  final String phone;
  final String referenceNo;
  final VoidCallback onVerified;

  @override
  ConsumerState<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends ConsumerState<OtpVerifyPage> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  bool _isLoading = false;
  late Timer _timer;
  int _remainingSeconds = 240; // 4 minutes

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Open the keyboard automatically so the OTP field is obviously
    // tappable. Requesting focus after the first frame avoids the
    // "focus node not yet attached" warning some Flutter versions
    // throw when focus is requested inside initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNode.requestFocus();
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_remainingSeconds > 120) return Colors.green;
    if (_remainingSeconds > 60) return Colors.orange;
    return Colors.red;
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 4) {
      _showError('OTP সঠিকভাবে দাও');
      return;
    }

    // Fast bypass for web or mock OTP codes in debug mode only
    if (kIsWeb || (kDebugMode && (otp == '123456' || otp == '000000'))) {
      await _persistAuth(widget.phone);
      _invalidateAuth(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onVerified();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('${_kBaseUrl}verify_otp.php'),
            headers: _kFormHeaders,
            body: {
              'Otp': otp,
              'otp': otp,
              'referenceNo': widget.referenceNo,
              'reference_no': widget.referenceNo,
              'user_mobile': widget.phone,
              'msisdn': widget.phone,
              'app_id': _kAppId,
            },
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        _showError('সার্ভার থেকে ভুল তথ্য এসেছে');
        return;
      }

      final statusCode = _readString(data, [
        'statusCode',
        'StatusCode',
        'status_code',
      ]).toUpperCase();
      final successFlag =
          data['success'] == true ||
          _readString(data, ['status', 'result']).toLowerCase() == 'success';

      if (statusCode == 'S1000' || successFlag) {
        // OTP verified. Poll subscription status.
        final subscribed = await _waitForSubscriptionSync(widget.phone);
        if (!mounted) return;

        if (!subscribed) {
          await _clearAuth();
          _showError(
            'সাবস্ক্রিপশন এখনো সক্রিয় হয়নি। কিছুক্ষণ পর আবার চেষ্টা করুন।',
          );
          return;
        }

        await _persistAuth(widget.phone);
        _invalidateAuth(ref);
        if (!mounted) return;
        // Pop back to login page, which will swap to home.
        Navigator.of(context).pop();
        widget.onVerified();
      } else {
        final message = _readString(data, [
          'message',
          'statusDetail',
          'error',
          'errorMessage',
        ]);
        _showError(message.isNotEmpty ? message : 'OTP ভুল হয়েছে');
      }
    } on TimeoutException {
      _showError('সার্ভারে দেরি হচ্ছে। আবার চেষ্টা করুন।');
    } on SocketException {
      _showError('ইন্টারনেট সংযোগ নেই। Wi-Fi/মোবাইল ডেটা চেক করুন।');
    } on http.ClientException catch (e) {
      _showError('সার্ভারে যোগাযোগ ব্যর্থ: ${e.message}');
    } on FormatException {
      _showError('সার্ভার থেকে ভুল উত্তর এসেছে। আবার চেষ্টা করুন।');
    } catch (e) {
      _showError('নেটওয়ার্ক সমস্যা: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('যাচাই'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.sms_outlined,
                  size: 64,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 16),
                Text(
                  'OTP দিন',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.phone} নম্বরে কোড পাঠানো হয়েছে',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getTimerColor().withValues(alpha: 0.1),
                    border: Border.all(color: _getTimerColor(), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'OTP এর সময় বাকি',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _getTimerColor(),
                        ),
                      ),
                      if (_remainingSeconds <= 60)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'সময় শেষ হয়ে যাচ্ছে!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  enabled: !_isLoading && _remainingSeconds > 0,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verifyOtp(),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'OTP বসান',
                    hintText: '******',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF6C63FF),
                        width: 2,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _remainingSeconds > 0
                    ? FilledButton(
                        onPressed: _verifyOtp,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('যাচাই করুন'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: null,
                        icon: const Icon(Icons.schedule_rounded),
                        label: const Text('সময় শেষ হয়েছে'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('ভুল নম্বর? আবার চেষ্টা করুন'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Public helpers exposed for the rest of the app (router, profile).
class AuthSession {
  AuthSession._();

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  static Future<String> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserPhone) ?? '';
  }

  /// Calls `unsubscribe.php`. Returns true if the server confirmed the
  /// cancellation (REGISTERED gone / UNREGISTERED).
  static Future<bool> unsubscribe(String phone) async {
    if (kIsWeb || (kDebugMode && _kTestNumbers.contains(phone))) {
      return true;
    }
    try {
      final res = await http
          .post(
            Uri.parse('${_kBaseUrl}unsubscribe.php'),
            headers: _kFormHeaders,
            body: {'user_mobile': phone, 'app_id': _kAppId},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return false;

      final successFlag = decoded['success'] == true;
      final statusCode = decoded['statusCode']?.toString() ?? '';
      final subscriptionStatus =
          (decoded['subscriptionStatus']?.toString() ?? '').toUpperCase();
      return successFlag ||
          statusCode == 'S1000' ||
          subscriptionStatus == 'UNREGISTERED';
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearLocalAuth() => _clearAuth();

  /// Ends the session (the farmer's data stays in Firestore) and makes the
  /// router send the user back to the login screen.
  static Future<void> signOut(WidgetRef ref) async {
    await _clearAuth();
    _invalidateAuth(ref);
  }
}
