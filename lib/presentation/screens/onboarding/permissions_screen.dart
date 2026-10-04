import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../providers/app_providers.dart';

class _PermissionItem {
  const _PermissionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.granted,
    required this.permanentlyDenied,
    required this.request,
  });
  final String title;
  final String description;
  final IconData icon;
  final bool granted;
  final bool permanentlyDenied;
  final Future<bool> Function() request;
}

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _busy = false;
  bool _cameraGranted = false;
  bool _micGranted = false;
  bool _storageGranted = false;
  bool _cameraLocked = false;
  bool _micLocked = false;
  bool _storageLocked = false;

  @override
  void initState() {
    super.initState();
    _refreshInitialStatus();
  }

  Future<void> _refreshInitialStatus() async {
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final stor = await Permission.storage.status;
    if (!mounted) return;
    setState(() {
      _cameraGranted = cam.isGranted || cam.isLimited;
      _micGranted = mic.isGranted || mic.isLimited;
      _storageGranted = stor.isGranted || stor.isLimited;
      _cameraLocked = cam.isPermanentlyDenied || cam.isRestricted;
      _micLocked = mic.isPermanentlyDenied || mic.isRestricted;
      _storageLocked = stor.isPermanentlyDenied || stor.isRestricted;
    });
  }

  Future<bool> _runRequest(Future<bool> Function() task) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      return await task();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _requestCamera() async {
    final ok = await ref.read(permissionServiceProvider).ensureCamera();
    if (mounted) {
      final status = await Permission.camera.status;
      setState(() {
        _cameraGranted = ok;
        _cameraLocked = status.isPermanentlyDenied || status.isRestricted;
      });
    }
    return ok;
  }

  Future<bool> _requestMic() async {
    final ok = await ref.read(permissionServiceProvider).ensureMicrophone();
    if (mounted) {
      final status = await Permission.microphone.status;
      setState(() {
        _micGranted = ok;
        _micLocked = status.isPermanentlyDenied || status.isRestricted;
      });
    }
    return ok;
  }

  Future<bool> _requestStorage() async {
    final ok = await ref.read(permissionServiceProvider).ensureStorage();
    if (mounted) {
      final status = await Permission.storage.status;
      setState(() {
        _storageGranted = ok;
        _storageLocked = status.isPermanentlyDenied || status.isRestricted;
      });
    }
    return ok;
  }

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    ref.invalidate(onboardingCompleteProvider);
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final items = <_PermissionItem>[
      _PermissionItem(
        title: AppStrings.cameraAccess,
        description: AppStrings.cameraAccessDesc,
        icon: Icons.camera_alt,
        granted: _cameraGranted,
        permanentlyDenied: _cameraLocked,
        request: () => _runRequest(_requestCamera),
      ),
      _PermissionItem(
        title: AppStrings.microphoneAccess,
        description: AppStrings.microphoneAccessDesc,
        icon: Icons.mic,
        granted: _micGranted,
        permanentlyDenied: _micLocked,
        request: () => _runRequest(_requestMic),
      ),
      _PermissionItem(
        title: AppStrings.storageAccess,
        description: AppStrings.storageAccessDesc,
        icon: Icons.folder,
        granted: _storageGranted,
        permanentlyDenied: _storageLocked,
        request: () => _runRequest(_requestStorage),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.permissionsTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              AppStrings.permissionsIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final item in items)
              _PermissionCard(
                title: item.title,
                description: item.description,
                icon: item.icon,
                granted: item.granted,
                busy: _busy,
                onTap: item.request,
                onOpenSettings: _openSettings,
                permanentlyDenied: item.permanentlyDenied,
              ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              onPressed: _busy ? null : _continue,
              label: AppStrings.continue_,
              fullWidth: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _continue,
                child: const Text(AppStrings.skipForNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.granted,
    required this.busy,
    required this.onTap,
    required this.onOpenSettings,
    required this.permanentlyDenied,
  });
  final String title;
  final String description;
  final IconData icon;
  final bool granted;
  final bool busy;
  final Future<bool> Function() onTap;
  final Future<void> Function() onOpenSettings;
  final bool permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    final statusColor = granted ? AppColors.primary : Colors.black54;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(
                  alpha: granted ? 0.2 : 0.1,
                ),
                child: Icon(icon, color: statusColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (granted)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.check_circle, color: AppColors.primary),
                )
              else if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                TextButton(
                  onPressed: () async {
                    await onTap();
                  },
                  child: Text(
                    permanentlyDenied ? AppStrings.granted : AppStrings.grant,
                  ),
                ),
            ],
          ),
          if (permanentlyDenied) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'অনুমতি স্থায়ীভাবে বন্ধ আছে। সেটিংস থেকে চালু করুন।',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('সেটিংস'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
