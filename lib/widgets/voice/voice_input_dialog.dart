import 'package:flutter/material.dart';

import '../../core/dialogs/app_dialogs.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../services/voice_service.dart';

/// Shows a Google-style voice input dialog. Returns the transcribed text when
/// the user finishes speaking, or null if dismissed or on error.
Future<String?> showVoiceInputDialog(BuildContext context) async {
  if (!context.mounted) return null;

  await VoiceService.initialize();
  if (!VoiceService.isAvailable) {
    if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('common.error')),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
    return null;
  }

  String partialText = '';
  String finalText = '';
  bool isListening = false;
  String? resultText;
  final scaffoldContext = context;

  if (!context.mounted) return null;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Google',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () async {
                    if (isListening) {
                      await VoiceService.stop();
                      setDialogState(() => isListening = false);
                      return;
                    }
                    setDialogState(() {
                      isListening = true;
                      partialText = '';
                      finalText = '';
                    });
                    await VoiceService.listen(
                      onResult: (text) {
                        if (dialogContext.mounted) {
                          resultText = text;
                          setDialogState(() {
                            finalText = text;
                            partialText = '';
                          });
                          VoiceService.stop();
                          setDialogState(() => isListening = false);
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      onPartialResult: (text) {
                        if (dialogContext.mounted) {
                          setDialogState(() => partialText = text);
                        }
                      },
                      onDone: () {
                        if (dialogContext.mounted) {
                          setDialogState(() => isListening = false);
                        }
                      },
                      onError: (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() => isListening = false);
                          if (scaffoldContext.mounted) {
                            if (error
                                .toString()
                                .toLowerCase()
                                .contains('permission')) {
                              Navigator.of(dialogContext).pop();
                              showPermissionDeniedDialog(scaffoldContext);
                            } else {
                              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${scaffoldContext.t('common.error')}: $error',
                                  ),
                                  backgroundColor: AppColors.destructive,
                                ),
                              );
                            }
                          }
                        }
                      },
                    );
                  },
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4285F4).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (partialText.isNotEmpty || finalText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      finalText.isNotEmpty ? finalText : partialText,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else if (isListening)
                  const _GoogleVoiceAnimatedDots()
                else
                  Text(
                    context.t('voice.tap.to.start'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ),
  );

  return resultText;
}

/// Animated dots indicator for Google-style voice dialog (listening state)
class _GoogleVoiceAnimatedDots extends StatefulWidget {
  const _GoogleVoiceAnimatedDots();

  @override
  State<_GoogleVoiceAnimatedDots> createState() =>
      _GoogleVoiceAnimatedDotsState();
}

class _GoogleVoiceAnimatedDotsState extends State<_GoogleVoiceAnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_controller.value + (i * 0.2)) % 1.0;
              final t = phase < 0.5 ? phase * 2 : 2 - phase * 2;
              final scale = 0.65 + (0.35 * t.clamp(0.0, 1.0));
              final opacity = 0.5 + (0.5 * t.clamp(0.0, 1.0));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
