import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import 'package:provider/provider.dart';

/// Simple custom camera screen:
/// - Bottom bar: capture + gallery
/// - After capture/pick, navigates to `/scan-crop` with the image in `extra`
class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  final ImagePicker _picker = ImagePicker();
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Don't dispose here.
    // Disposing during route transitions can make `CameraPreview` rebuild
    // with a disposed controller and crash.
    super.deactivate();
  }

  Future<void> _ensureScannerAccess() async {
    final premiumProvider = context.read<PremiumProvider>();
    if (!premiumProvider.canUseScannerSync()) {
      ProNavigation.tryOpen(context, replace: false);
      throw Exception('scanner_limit');
    }
  }

  Future<void> _handleCapture() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _ensureScannerAccess();
      // Prefer true in-app camera capture.
      if (_controller != null && _controller!.value.isInitialized) {
        final XFile file = await _controller!.takePicture();
        // Stop preview before navigating away (reduces camera resource issues).
        try {
          await _controller?.pausePreview();
        } catch (_) {}
        if (!mounted) return;
        // Replace route so this screen gets disposed naturally.
        context.go('/scan-crop', extra: file);
      } else {
        // Fallback if camera plugin fails to init.
        final XFile? file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (file != null && mounted) {
          context.go('/scan-crop', extra: file);
        }
      }
    } catch (_) {
      // Swallow errors here; IngredientScannerScreen will show proper messages.
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handlePickFromGallery() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _ensureScannerAccess();
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        // It's safer to replace location so the camera screen doesn't stay alive.
        context.go('/scan-crop', extra: image);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Text(
                    context.t('recipes.scan'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // balance layout
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: _initFuture,
                builder: (context, snapshot) {
                  if (_controller == null || !_controller!.value.isInitialized) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }
                    return Center(
                      child: Text(
                        context.t('common.error'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.previewSize?.height ?? 1,
                            height: _controller!.value.previewSize?.width ?? 1,
                            child: CameraPreview(_controller!),
                          ),
                        ),
                      ),
                      if (_isBusy)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x55000000),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.6)
                    : Colors.black.withOpacity(0.75),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery
                  IconButton(
                    iconSize: 30,
                    color: Colors.white,
                    onPressed: _handlePickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  // Capture
                  GestureDetector(
                    onTap: _handleCapture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

