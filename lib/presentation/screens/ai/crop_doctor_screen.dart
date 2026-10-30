import 'dart:async';
import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/disease_api_service.dart';
import '../../../core/services/rice_disease_classifier.dart';
import '../../../core/services/scan_prediction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/diagnosis.dart';
import '../../../data/models/disease.dart';
import '../../providers/app_providers.dart';
import '../../widgets/bottom_action_bar.dart';
import 'doctor_crops.dart';

class CropDoctorScreen extends ConsumerStatefulWidget {
  const CropDoctorScreen({super.key, this.initialCropId});

  /// Pre-selects a crop, e.g. `/ai/scan?crop=tomato`.
  final String? initialCropId;

  @override
  ConsumerState<CropDoctorScreen> createState() => _CropDoctorScreenState();
}

/// Whether the online server can diagnose the selected crop right now.
enum _ServerState { checking, waking, ready, noModel, unreachable }

class _CropDoctorScreenState extends ConsumerState<CropDoctorScreen>
    with SingleTickerProviderStateMixin {
  late DoctorCrop _crop = DoctorCrop.byId(widget.initialCropId);

  late final AnimationController _scanAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  String? _imagePath;
  bool _loading = false;

  _ServerState _server = _ServerState.checking;
  ServerHealth? _health;
  DateTime? _healthAt;

  @override
  void initState() {
    super.initState();
    if (_crop.isOnline) _checkServer();
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

  void _selectCrop(DoctorCrop crop) {
    if (crop.id == _crop.id) return;
    HapticFeedback.selectionClick();
    setState(() => _crop = crop);
    if (crop.isOnline) _checkServer();
  }

  // সার্ভার চালু কি না ও এই ফসলের model আছে কি না; ৩০ সেকেন্ড মনে রাখা হয়
  Future<void> _checkServer({bool force = false}) async {
    final checkedAt = _healthAt;
    final fresh =
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < const Duration(seconds: 30);
    if (!force && fresh) {
      setState(() => _server = _serverStateFor(_crop, _health));
      return;
    }
    if (_server != _ServerState.checking && _server != _ServerState.waking) {
      setState(() => _server = _ServerState.checking);
    }
    // free সার্ভার ঘুমিয়ে থাকলে জাগতে প্রায় ১ মিনিট লাগে; ততক্ষণ "জাগছে" দেখানো
    final slow = Timer(const Duration(seconds: 4), () {
      if (mounted && _server == _ServerState.checking) {
        setState(() => _server = _ServerState.waking);
      }
    });
    final health = await ref.read(diseaseApiProvider).health();
    slow.cancel();
    if (!mounted) return;
    _health = health;
    _healthAt = health == null ? null : DateTime.now();
    setState(() => _server = _serverStateFor(_crop, health));
  }

  static _ServerState _serverStateFor(DoctorCrop crop, ServerHealth? health) {
    if (health == null) return _ServerState.unreachable;
    return health.isReady(crop.id) ? _ServerState.ready : _ServerState.noModel;
  }

  // ছবি তোলা বা নির্বাচন
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    // বড় ছবি ছোট করে নিলে decode ও upload দ্রুত হয়; model 288px-এই চলে
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  // ধান ফোনেই, বাকি ফসল সার্ভারে
  Future<void> _processAndNavigate() async {
    final path = _imagePath;
    if (path == null || _loading) return;
    final crop = _crop;

    setState(() => _loading = true);
    _scanAnim.repeat(reverse: true);
    ScanPrediction? prediction;
    DiseaseApiException? apiError;
    try {
      prediction = crop.isOnline
          ? await _classifyOnline(crop, path)
          : await _classifyOffline(path);
    } on DiseaseApiException catch (e) {
      apiError = e;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('বিশ্লেষণ করা যায়নি: $e')));
      }
    } finally {
      _scanAnim.stop();
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    if (apiError != null) {
      await _showOnlineError(apiError, crop);
      return;
    }
    if (prediction == null) return;
    if (crop.isOnline) setState(() => _server = _ServerState.ready);

    final top = prediction.top;
    if (notLeafLabels.contains(top.label)) {
      await _showProblemDialog(
        icon: Icons.image_search_rounded,
        title: 'এটি ${crop.possessiveBn} পাতা নয়',
        message:
            'ছবিতে ${crop.possessiveBn} পাতা পাওয়া যায়নি। আক্রান্ত পাতার '
            'কাছ থেকে ছবি তুলুন, অথবা উপরে সঠিক ফসল বাছুন।',
        actionLabel: 'নতুন ছবি তুলুন',
        actionIcon: Icons.photo_camera_rounded,
        onAction: () => _pickImage(ImageSource.camera),
      );
      return;
    }

    // সার্ভার নিজের model-এর threshold দিয়ে রায় দেয়; ধানের জন্য app-এর নিজের
    final confident =
        prediction.isConfident ??
        top.score >= RiceDiseaseClassifier.confidentThreshold;
    final probable =
        prediction.isProbable ??
        top.score >= RiceDiseaseClassifier.minThreshold;
    if (!confident && !probable) {
      await _showProblemDialog(
        icon: Icons.help_outline_rounded,
        title: 'রোগ চেনা যায়নি',
        message:
            'ছবিটি থেকে নিশ্চিত হওয়া যাচ্ছে না। দিনের আলোয়, '
            'একটি আক্রান্ত পাতা কাছ থেকে, দাগ মাঝখানে রেখে আবার ছবি তুলুন।',
        actionLabel: 'নতুন ছবি তুলুন',
        actionIcon: Icons.photo_camera_rounded,
        onAction: () => _pickImage(ImageSource.camera),
      );
      return;
    }

    final diagnosis = _buildDiagnosis(
      crop,
      prediction,
      path,
      confident: confident,
    );
    await _save(diagnosis);
    if (!mounted) return;
    await context.push(
      '/ai/scan/result',
      extra: <String, dynamic>{
        'cropName': crop.nameBn,
        'diagnosis': diagnosis,
        'imagePath': path,
        'fromScan': true,
      },
    );
    // ফলাফল দেখে ফিরে এলে নতুন স্ক্যানের জন্য পরিষ্কার
    if (mounted) setState(() => _imagePath = null);
  }

  Future<ScanPrediction> _classifyOffline(String path) async {
    final classifier = await ref.read(riceClassifierProvider.future);
    // inference খুব দ্রুত; scan animation যেন চোখে পড়ে তাই অল্প সময় ধরে রাখা
    final results = await Future.wait([
      classifier.classify(File(path)),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    return results.first as ScanPrediction;
  }

  Future<ScanPrediction> _classifyOnline(DoctorCrop crop, String path) async {
    final result = await ref
        .read(diseaseApiProvider)
        .predictImage(File(path), crop: crop.id);
    return result.toScanPrediction();
  }

  Diagnosis _buildDiagnosis(
    DoctorCrop crop,
    ScanPrediction prediction,
    String path, {
    required bool confident,
  }) {
    final top = prediction.top;
    final info = crop.diseases[top.label];
    String nameOf(LabelScore s) =>
        crop.diseases[s.label]?.displayName ?? s.nameBn ?? s.label;

    final notes = <String>[
      if (!confident)
        'ফলাফল পুরোপুরি নিশ্চিত নয়। নিচের অন্য সম্ভাবনাগুলোও দেখুন।',
      if (info?.needsExpertCheck ?? false)
        'এই রোগ দেখতে অন্য দাগ রোগের মতো। ওষুধ দেওয়ার আগে কৃষি '
            'অফিসারকে দেখিয়ে নিশ্চিত হোন।',
      if (info == null)
        'এই সমস্যার বিস্তারিত পরামর্শ অ্যাপে এখনো নেই। কৃষি অফিসারের '
            'পরামর্শ নিন।',
    ];

    return Diagnosis(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cropName: crop.nameBn,
      diseaseName: nameOf(top),
      confidence: top.score,
      isConfident: confident,
      severity: info?.severity ?? Severity.medium,
      scannedAt: DateTime.now(),
      symptoms: info?.symptoms ?? const [],
      causes: info?.causes ?? const [],
      prevention: info?.prevention ?? const [],
      management: info?.management ?? const [],
      fertilizer: info?.fertilizer ?? const [],
      alternatives: confident
          ? const []
          : prediction.ranked
                .skip(1)
                .where(
                  (s) => !notLeafLabels.contains(s.label) && s.score >= 0.05,
                )
                .take(2)
                .map(
                  (s) =>
                      DiagnosisCandidate(name: nameOf(s), confidence: s.score),
                )
                .toList(),
      notes: notes.isEmpty ? null : notes.join('\n'),
      imagePath: path,
    );
  }

  // ইতিহাসে জমা; ব্যর্থ হলেও ফলাফল দেখানো আটকাবে না
  Future<void> _save(Diagnosis diagnosis) async {
    try {
      final repo = await ref.read(diagnosisRepoProvider.future);
      await repo.save(diagnosis);
      ref.invalidate(diagnosesProvider);
    } catch (_) {
      /* best-effort */
    }
  }

  Future<void> _showOnlineError(DiseaseApiException e, DoctorCrop crop) {
    void retry() => _processAndNavigate();
    switch (e.kind) {
      case DiseaseApiErrorKind.network:
        setState(() => _server = _ServerState.unreachable);
        return _showProblemDialog(
          icon: Icons.wifi_off_rounded,
          title: 'ইন্টারনেট সংযোগ নেই',
          message:
              '${crop.possessiveBn} রোগ নির্ণয় অনলাইনে হয়। ইন্টারনেট '
              'চালু করে আবার চেষ্টা করুন।',
          actionLabel: 'আবার চেষ্টা করুন',
          actionIcon: Icons.refresh_rounded,
          onAction: retry,
        );
      case DiseaseApiErrorKind.timeout:
        return _showProblemDialog(
          icon: Icons.hourglass_bottom_rounded,
          title: 'সার্ভার সাড়া দিচ্ছে না',
          message:
              'ইন্টারনেট ধীর অথবা সার্ভার ব্যস্ত। একটু পরে আবার '
              'চেষ্টা করুন।',
          actionLabel: 'আবার চেষ্টা করুন',
          actionIcon: Icons.refresh_rounded,
          onAction: retry,
        );
      case DiseaseApiErrorKind.modelUnavailable:
        setState(() => _server = _ServerState.noModel);
        return _showProblemDialog(
          icon: Icons.construction_rounded,
          title: '${crop.possessiveBn} মডেল এখনো প্রস্তুত নয়',
          message:
              'সার্ভারে এই ফসলের মডেল এখনো যোগ হয়নি। ততক্ষণ ধানের রোগ '
              'ইন্টারনেট ছাড়াই নির্ণয় করতে পারেন।',
        );
      case DiseaseApiErrorKind.server:
      case DiseaseApiErrorKind.badResponse:
        return _showProblemDialog(
          icon: Icons.cloud_off_rounded,
          title: 'সার্ভারে সমস্যা হয়েছে',
          message:
              'এই মুহূর্তে রোগ নির্ণয় করা যাচ্ছে না। একটু পরে আবার '
              'চেষ্টা করুন।',
          actionLabel: 'আবার চেষ্টা করুন',
          actionIcon: Icons.refresh_rounded,
          onAction: retry,
        );
    }
  }

  Future<void> _showProblemDialog({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) async {
    final crop = _crop;
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: IconBadge(
          icon: icon,
          tint: crop.tint,
          color: crop.color,
          size: 56,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(actionLabel == null ? 'ঠিক আছে' : 'বাতিল'),
          ),
          if (actionLabel != null)
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: crop.color),
              icon: Icon(actionIcon ?? Icons.check_rounded, size: 18),
              label: Text(actionLabel),
            ),
        ],
      ),
    );
    if (act == true && mounted) onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final crop = _crop;
    final hasImage = _imagePath != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('রোগ নির্ণয়'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'স্ক্যান ইতিহাস',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/ai/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroHeader(crop: crop),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle(title: 'ফসল বাছুন', trailing: _ModeLegend()),
            const SizedBox(height: AppSpacing.md),
            _CropPicker(
              selected: crop,
              enabled: !_loading,
              onSelect: _selectCrop,
            ),
            const SizedBox(height: AppSpacing.md),
            _ModeBanner(
              crop: crop,
              server: _server,
              onRetry: () => _checkServer(force: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PhotoArea(
              crop: crop,
              imagePath: _imagePath,
              loading: _loading,
              scanAnimation: _scanAnim,
              onPick: () => _pickImage(ImageSource.gallery),
              onClear: () => setState(() => _imagePath = null),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _SourceTile(
                    crop: crop,
                    icon: Icons.photo_camera_rounded,
                    label: 'ক্যামেরা',
                    subtitle: 'এখনই ছবি তুলুন',
                    onTap: _loading
                        ? null
                        : () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SourceTile(
                    crop: crop,
                    icon: Icons.photo_library_rounded,
                    label: 'গ্যালারি',
                    subtitle: 'আগের ছবি বাছুন',
                    onTap: _loading
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _TipsSection(),
            const SizedBox(height: AppSpacing.xxl),
            _SupportedProblems(crop: crop),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: !hasImage
              ? 'আগে একটি ছবি দিন'
              : crop.isOnline
              ? 'অনলাইনে রোগ নির্ণয় করুন'
              : 'রোগ নির্ণয় করুন',
          icon: crop.isOnline
              ? Icons.cloud_upload_rounded
              : Icons.biotech_rounded,
          loading: _loading,
          background: crop.color,
          onPressed: hasImage ? _processAndNavigate : null,
        ),
      ),
    );
  }
}

/// Stack layout for AnimatedSwitcher that keeps children top-left aligned
/// instead of centring them mid-transition.
Widget _topLeftSwitcherLayout(Widget? current, List<Widget> previous) =>
    Stack(alignment: Alignment.topLeft, children: [...previous, ?current]);

/// Gradient intro card in the selected crop's colours.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.crop});

  final DoctorCrop crop;

  @override
  Widget build(BuildContext context) {
    final problems = crop.problems.toList();
    final hasPest = problems.any((p) => p.isPest);
    final countLabel =
        '${AppNumber.bangla(problems.length)}টি রোগ${hasPest ? ' ও পোকা' : ''}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [crop.deepColor, crop.color],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: crop.color.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'এআই ক্রপ ডাক্তার',
                  style: AppTextStyles.h3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xxs),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: _topLeftSwitcherLayout,
                  child: Text(
                    '${crop.possessiveBn} পাতার ছবি দিন, কয়েক সেকেন্ডেই রোগ ও '
                    'করণীয় জানুন',
                    key: ValueKey(crop.id),
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: AppColors.textOnDarkMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _HeroPill(
                      icon: crop.isOnline
                          ? Icons.cloud_rounded
                          : Icons.wifi_off_rounded,
                      label: crop.isOnline
                          ? 'অনলাইনে নির্ণয়'
                          : 'ইন্টারনেট ছাড়াই',
                    ),
                    _HeroPill(
                      icon: Icons.coronavirus_outlined,
                      label: countLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                crop.emoji,
                key: ValueKey(crop.id),
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.titleLarge)),
        ?trailing,
      ],
    );
  }
}

/// "● অফলাইন  ● অনলাইন" key for the badges on the crop tiles.
class _ModeLegend extends StatelessWidget {
  const _ModeLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeDot(online: false, size: 15),
        SizedBox(width: AppSpacing.xxs),
        Text('অফলাইন', style: AppTextStyles.caption),
        SizedBox(width: AppSpacing.sm + 2),
        _ModeDot(online: true, size: 15),
        SizedBox(width: AppSpacing.xxs),
        Text('অনলাইন', style: AppTextStyles.caption),
      ],
    );
  }
}

class _ModeDot extends StatelessWidget {
  const _ModeDot({required this.online, this.size = 20});

  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: online ? AppColors.info : AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size >= 18 ? 2 : 1.5),
      ),
      child: Icon(
        online ? Icons.cloud_rounded : Icons.wifi_off_rounded,
        size: size * 0.55,
        color: Colors.white,
      ),
    );
  }
}

class _CropPicker extends StatelessWidget {
  const _CropPicker({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final DoctorCrop selected;
  final bool enabled;
  final ValueChanged<DoctorCrop> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, crop) in doctorCrops.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _CropTile(
              crop: crop,
              selected: crop.id == selected.id,
              onTap: enabled ? () => onSelect(crop) : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({
    required this.crop,
    required this.selected,
    required this.onTap,
  });

  final DoctorCrop crop;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Semantics(
      button: true,
      selected: selected,
      label: '${crop.nameBn}, ${crop.isOnline ? 'অনলাইন' : 'অফলাইন'}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? crop.tint : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? crop.color : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: crop.color.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                2,
                AppSpacing.md,
                2,
                AppSpacing.sm + 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.1 : 1,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : crop.tint,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            crop.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -5,
                        bottom: -3,
                        child: _ModeDot(online: crop.isOnline, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    crop.nameBn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? crop.deepColor
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Explains where the diagnosis runs; for online crops also shows whether
/// the server is reachable and has this crop's model.
class _ModeBanner extends StatelessWidget {
  const _ModeBanner({
    required this.crop,
    required this.server,
    required this.onRetry,
  });

  final DoctorCrop crop;
  final _ServerState server;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final online = crop.isOnline;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(online),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: online ? AppColors.tintBlue : AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              online ? Icons.cloud_upload_outlined : Icons.offline_pin_rounded,
              size: 22,
              color: online ? AppColors.info : AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online ? 'অনলাইনে নির্ণয় হয়' : 'ইন্টারনেট ছাড়াই কাজ করে',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: online
                          ? const Color(0xFF1E3A8A)
                          : AppColors.primaryOnContainer,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    online
                        ? 'ছবি সার্ভারে পাঠিয়ে রোগ দেখা হয়, ইন্টারনেট লাগবে'
                        : 'মডেল ফোনেই আছে, মাঠে নেট ছাড়াই ব্যবহার করুন',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (online) ...[
              const SizedBox(width: AppSpacing.sm),
              _ServerChip(state: server, onRetry: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip({required this.state, required this.onRetry});

  final _ServerState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      _ServerState.checking => (AppColors.textMuted, 'যাচাই হচ্ছে'),
      _ServerState.waking => (AppColors.warning, 'সার্ভার জাগছে'),
      _ServerState.ready => (AppColors.success, 'সার্ভার চালু'),
      _ServerState.noModel => (AppColors.warning, 'মডেল আসছে'),
      _ServerState.unreachable => (AppColors.danger, 'সংযোগ নেই'),
    };
    final canRetry =
        state == _ServerState.unreachable || state == _ServerState.noModel;
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: canRetry ? onRetry : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == _ServerState.checking ||
                  state == _ServerState.waking)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: color,
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (canRetry) ...[
                const SizedBox(width: AppSpacing.xxs),
                Icon(Icons.refresh_rounded, size: 14, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo slot: dashed drop-zone when empty, preview with a scanning
/// overlay while the model runs.
class _PhotoArea extends StatelessWidget {
  const _PhotoArea({
    required this.crop,
    required this.imagePath,
    required this.loading,
    required this.scanAnimation,
    required this.onPick,
    required this.onClear,
  });

  final DoctorCrop crop;
  final String? imagePath;
  final bool loading;
  final Animation<double> scanAnimation;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final radius = BorderRadius.circular(AppRadius.xl);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        // default layout loosens constraints and would shrink the drop-zone
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: path == null
            ? CustomPaint(
                key: ValueKey('empty-${crop.id}'),
                foregroundPainter: _DashedBorderPainter(
                  color: crop.color.withValues(alpha: 0.45),
                  radius: AppRadius.xl,
                ),
                child: Material(
                  color: crop.tint,
                  borderRadius: radius,
                  child: InkWell(
                    onTap: onPick,
                    borderRadius: radius,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconBadge(
                          icon: Icons.add_a_photo_rounded,
                          tint: Colors.white,
                          color: crop.color,
                          size: 68,
                          iconSize: 30,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${crop.possessiveBn} পাতার ছবি দিন',
                          style: AppTextStyles.title.copyWith(
                            color: crop.deepColor,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        const Text(
                          'ট্যাপ করে গ্যালারি থেকে বাছুন',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ClipRRect(
                key: ValueKey(path),
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(path), fit: BoxFit.cover),
                    if (loading)
                      _ScanningOverlay(
                        animation: scanAnimation,
                        glow: Color.lerp(crop.color, Colors.white, 0.55)!,
                        label: crop.isOnline
                            ? 'সার্ভারে পাঠানো হচ্ছে…'
                            : 'পাতা বিশ্লেষণ হচ্ছে…',
                      )
                    else ...[
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: IconButton(
                          tooltip: 'ছবি সরান',
                          onPressed: onClear,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.4,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                      const Positioned(
                        left: AppSpacing.md,
                        bottom: AppSpacing.md,
                        child: _ImageBadge(
                          icon: Icons.check_circle_rounded,
                          label: 'ছবি প্রস্তুত',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({
    required this.icon,
    required this.label,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Icon(icon, size: 16, color: const Color(0xFF86EFAC)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dim layer + a glowing line sweeping over the leaf while it's analysed.
class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay({
    required this.animation,
    required this.glow,
    required this.label,
  });

  final Animation<double> animation;
  final Color glow;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
        AnimatedBuilder(
          animation: animation,
          builder: (_, _) => Align(
            alignment: Alignment(0, -1 + 2 * animation.value),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    glow.withValues(alpha: 0),
                    glow,
                    glow.withValues(alpha: 0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.7),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _ImageBadge(
              icon: Icons.biotech_rounded,
              label: label,
              busy: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 8.0;
    const gap = 6.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.8);
    final path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.crop,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final DoctorCrop crop;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                IconChip(
                  icon: icon,
                  tint: crop.tint,
                  color: crop.color,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.title),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ছবি তোলার নির্দেশনা — মাঠের ছবিতে model-এর ভুল কমায়।
class _TipsSection extends StatelessWidget {
  const _TipsSection();

  static const _tips = [
    (
      Icons.wb_sunny_outlined,
      'দিনের আলোয় তুলুন',
      AppColors.tintAmber,
      AppColors.accentDark,
    ),
    (
      Icons.zoom_in_rounded,
      'একটি পাতা কাছ থেকে',
      AppColors.tintGreen,
      AppColors.primary,
    ),
    (
      Icons.center_focus_strong_outlined,
      'দাগ ছবির মাঝখানে',
      AppColors.tintBlue,
      AppColors.info,
    ),
    (
      Icons.blur_off_rounded,
      'ছবি যেন ঝাপসা না হয়',
      AppColors.tintViolet,
      Color(0xFF7C3AED),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ভালো ফলাফলের জন্য', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (icon, text, tint, color) in _tips)
                  SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          IconChip(
                            icon: icon,
                            tint: tint,
                            color: color,
                            size: 34,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              text,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SupportedProblems extends StatelessWidget {
  const _SupportedProblems({required this.crop});

  final DoctorCrop crop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('যেসব সমস্যা চিনতে পারে', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${crop.possessiveBn} সুস্থ পাতাও আলাদা করে চেনে',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            layoutBuilder: _topLeftSwitcherLayout,
            child: Wrap(
              key: ValueKey(crop.id),
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final info in crop.problems)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          info.isPest
                              ? Icons.bug_report_outlined
                              : Icons.coronavirus_outlined,
                          size: 15,
                          color: crop.color,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          info.nameBn,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
