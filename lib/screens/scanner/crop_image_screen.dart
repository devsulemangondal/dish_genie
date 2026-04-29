import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/l10n_extension.dart';
import '../../services/app_open_ad_manager.dart';

class CropImageScreen extends StatefulWidget {
  const CropImageScreen({super.key, required this.image});

  final XFile image;

  @override
  State<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<CropImageScreen> {
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    // Auto-open the native crop UI as soon as this screen is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startCrop();
    });
  }

  Future<void> _startCrop() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    try {
      // Cropper launches an external Activity on Android.
      // Suppress resume-triggered App Open Ads for this flow.
      AppOpenAdManager.instance.suppressNextResume(reason: 'image_cropper');

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: widget.image.path,
        compressFormat: ImageCompressFormat.png,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: context.t('recipes.scan'),
            toolbarColor: isDark ? Colors.black : Colors.white,
            toolbarWidgetColor: isDark ? Colors.white : Colors.black,
            statusBarColor: isDark ? Colors.black : Colors.white,
            activeControlsWidgetColor: theme.colorScheme.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: context.t('recipes.scan'),
          ),
        ],
      );

      if (!mounted) return;

      // If user cancels (presses X/back), go back to new Home.
      if (cropped == null) {
        context.go('/');
        return;
      }

      context.go('/scan', extra: XFile(cropped.path));
    } catch (_) {
      if (!mounted) return;
      // If crop fails, go back to home (avoid accidental navigation).
      context.go('/');
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                context.t('recipes.scan'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

