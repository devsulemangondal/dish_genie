import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/ads/screen_native_ad_widget.dart';
import '../../widgets/ads/custom_native_ad_widget.dart';
import '../../providers/chat_provider.dart';
import '../../providers/premium_provider.dart';
import '../../data/models/chat_message.dart';
import '../../services/voice_service.dart';
import '../../core/dialogs/app_dialogs.dart';
import '../../services/card_ad_tracker.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/chat/typewriter_text.dart';

class ChatAssistantScreen extends StatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  // Helper to get localized message content
  String _getMessageContent(BuildContext context, String content) {
    if (content.startsWith('__L10N_KEY__:')) {
      final key = content.substring('__L10N_KEY__:'.length);
      return context.t(key);
    }
    return content;
  }

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isVoiceListening = false;
  String _voiceTranscript = '';
  int _previousMessageCount = 0;

  // Responsive helper methods
  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 16.0; // Small phones
    if (width < 400) return 20.0; // Medium phones
    return 32.0; // Large phones
  }

  double _getResponsiveSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 8.0;
    if (width < 400) return 10.0;
    return 12.0;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.of(context).textScaleFactor;
    if (width < 360) return baseSize * 0.9 * textScale;
    if (width < 400) return baseSize * 0.95 * textScale;
    return baseSize * textScale;
  }

  double _getResponsiveIconSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.85;
    if (width < 400) return baseSize * 0.9;
    return baseSize;
  }

  @override
  void initState() {
    super.initState();
    VoiceService.initialize();
    _trackCardScreenOpen();
  }

  /// Track when card screen is opened
  Future<void> _trackCardScreenOpen() async {
    // Check if user is premium (premium users don't see ads)
    final premiumProvider = Provider.of<PremiumProvider>(
      context,
      listen: false,
    );
    if (premiumProvider.isPremium) return;

    // Track the open action
    final openCount = await CardAdTracker.trackCardOpen();

    // Get the card_inter configuration (single value like "open5" or "back5" or "off")
    final cardInterConfig = RemoteConfigService.cardInter.trim().toLowerCase();

    // Check if card_inter is "off" - if so, don't show ad
    if (cardInterConfig != 'off' && cardInterConfig.isNotEmpty) {
      // Check if config starts with "open"
      if (cardInterConfig.startsWith('open')) {
        try {
          // Extract number after "open"
          final numStr = cardInterConfig.substring(4); // "open" is 4 characters
          final threshold = int.parse(numStr);
          if (threshold > 0) {
            // Show ad when counter >= threshold
            final shouldShowAd = openCount >= threshold;

            if (shouldShowAd) {
              // Show after a small delay to ensure screen is loaded
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (mounted) {
                  await AdService.showInterstitialAdForType(
                    adType: 'card',
                    context: context,
                    loadAdFunction: () => AdService.loadCardInterstitialAd(),
                    onAdDismissed: () {
                      // Reset counter after ad is shown
                      CardAdTracker.resetCardOpenCount();
                    },
                    onAdFailedToShow: (ad) {
                      // Reset counter even if ad fails to show
                      CardAdTracker.resetCardOpenCount();
                    },
                  );
                }
              });
            }
          }
        } catch (e) {
          // If parsing fails, don't show ad
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    VoiceService.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Check if user is premium (premium users don't see ads)
    final premiumProvider = Provider.of<PremiumProvider>(
      context,
      listen: false,
    );

    // Check if free user can send AI chef messages based on remote config
    if (!premiumProvider.isPremium) {
      if (!premiumProvider.canSendAiChefMessage()) {
        // Don't send message - input is disabled and limit message is shown
        return;
      }
    }

    final shouldShowAd = !premiumProvider.isPremium;

    if (shouldShowAd) {
      // Track the cooking AI start (first message)
      final messages = context.read<ChatProvider>().messages;
      if (messages.isEmpty) {
        // This is the first message - check for cooking AI interstitial
        final cookingAiCount = await CardAdTracker.trackCookingAiStart();

        // Get the cookingai_inter configuration (single integer string or "off")
        final cookingAiConfig = RemoteConfigService.cookingAiInter
            .trim()
            .toLowerCase();

        // Check if cookingai_inter is "off" - if so, don't show ad
        if (cookingAiConfig != 'off' && cookingAiConfig.isNotEmpty) {
          // Parse the threshold value (single integer string)
          bool meetsThreshold = false;
          try {
            final threshold = int.parse(cookingAiConfig);
            if (threshold > 0) {
              // Show ad when counter >= threshold
              meetsThreshold = cookingAiCount >= threshold;
            }
          } catch (e) {
            // If parsing fails, don't show ad
            meetsThreshold = false;
          }

          if (meetsThreshold) {
            // Show ad with loader (loader is handled in AdService)
            await AdService.showInterstitialAdForType(
              adType: 'cookingAi',
              context: context,
              loadAdFunction: () => AdService.loadCookingAiInterstitialAd(),
              onAdDismissed: () {
                // Reset counter after ad is shown
                CardAdTracker.resetCookingAiCount();
                _proceedWithMessage(text);
              },
              onAdFailedToShow: (ad) {
                // Reset counter even if ad fails to show
                CardAdTracker.resetCookingAiCount();
                _proceedWithMessage(text);
              },
            );
            return; // Don't proceed until ad is shown
          }
        }
      }
    }

    _proceedWithMessage(text);
  }

  Future<void> _proceedWithMessage(String text) async {
    if (!await ensureConnectedAndShowDialog(context)) return;
    _messageController.clear();

    // Increment AI chef message count for free users
    final premiumProvider = Provider.of<PremiumProvider>(
      context,
      listen: false,
    );
    premiumProvider.incrementAiChefMessageCount();

    final provider = context.read<ChatProvider>();
    await provider.sendMessage(text);
    // Scroll to bottom after a short delay to ensure message is rendered
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  Future<void> _handleBack() async {
    // Check if user is premium (premium users don't see ads)
    final premiumProvider = Provider.of<PremiumProvider>(
      context,
      listen: false,
    );

    if (!premiumProvider.isPremium) {
      // Track the back action
      final backCount = await CardAdTracker.trackCardBack();

      // Get the card_inter configuration (single value like "open5" or "back5" or "off")
      final cardInterConfig = RemoteConfigService.cardInter
          .trim()
          .toLowerCase();

      // Check if card_inter is "off" - if so, don't show ad
      if (cardInterConfig != 'off' && cardInterConfig.isNotEmpty) {
        // Check if config starts with "back"
        if (cardInterConfig.startsWith('back')) {
          try {
            // Extract number after "back"
            final numStr = cardInterConfig.substring(
              4,
            ); // "back" is 4 characters
            final threshold = int.parse(numStr);
            if (threshold > 0) {
              // Show ad when counter >= threshold
              final shouldShowAd = backCount >= threshold;

              if (shouldShowAd) {
                // Show ad with loader (loader is handled in AdService)
                await AdService.showInterstitialAdForType(
                  adType: 'card',
                  context: context,
                  loadAdFunction: () => AdService.loadCardInterstitialAd(),
                  onAdDismissed: () {
                    // Reset counter after ad is shown
                    CardAdTracker.resetCardBackCount();
                    if (mounted) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    }
                  },
                  onAdFailedToShow: (ad) {
                    // Reset counter even if ad fails to show
                    CardAdTracker.resetCardBackCount();
                    if (mounted) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    }
                  },
                );
                // Don't pop immediately, wait for ad callback
                return;
              }
            }
          } catch (e) {
            // If parsing fails, just pop
          }
        }
      }
    }

    // If no ad should be shown, pop normally
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isVoiceListening) {
      await VoiceService.stop();
      setState(() {
        _isVoiceListening = false;
        _voiceTranscript = '';
      });
    } else {
      setState(() {
        _isVoiceListening = true;
        _voiceTranscript = context.t('chat.listening');
      });

      await VoiceService.listen(
        onResult: (text) {
          _messageController.text = text;
          setState(() {
            _isVoiceListening = false;
            _voiceTranscript = '';
          });
        },
        onPartialResult: (text) {
          setState(() => _voiceTranscript = text);
        },
        onDone: () {
          setState(() {
            _isVoiceListening = false;
            _voiceTranscript = '';
          });
        },
        onError: (error) {
          setState(() {
            _isVoiceListening = false;
            _voiceTranscript = '';
          });
          if (mounted &&
              error.toString().toLowerCase().contains('permission')) {
            showPermissionDeniedDialog(context);
          }
        },
      );
    }
  }

  void _handleSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final premiumProvider = context.watch<PremiumProvider>();
    final messages = chatProvider.messages;
    final isLoading = chatProvider.isLoading;

    // Check if user can send AI chef messages
    final canSendMessage =
        premiumProvider.isPremium || premiumProvider.canSendAiChefMessage();
    final aiChefLimit = premiumProvider.getAiChefMessageLimit();
    final aiChefMessageCount = premiumProvider.aiChefMessageCount;

    // Determine if limit banner should be shown
    // Show banner if:
    // 1. User is not premium AND
    // 2. Either ai_chef is "off" (feature disabled) OR message count >= limit
    final shouldShowLimitBanner =
        !premiumProvider.isPremium &&
        (aiChefLimit == null || aiChefMessageCount >= aiChefLimit);

    // Scroll to bottom when new messages arrive (especially during streaming)
    if (messages.length != _previousMessageCount || isLoading) {
      _previousMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: const BottomNav(activeTab: 'chat'),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.gradientHeroDark
                    : AppColors.gradientHero,
              ),
            ),
            const FloatingSparkles(),
            SafeArea(
              child: Column(
                children: [
                  StickyHeader(
                    title: context.t('chat.title'),
                    onBack: _handleBack,
                    backgroundColor: Colors.transparent,
                    statusBarColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1F35)
                        : AppColors.genieBlush,
                    rightContent: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history),
                          onPressed: () => context.go('/chat-history'),
                          tooltip: context.t('chatHistory.title'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            chatProvider.startNewChat();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.t('chat.new.chat')),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          tooltip: context.t('chat.new.chat'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: messages.isEmpty
                        ? _buildEmptyState(context)
                        : _buildMessagesList(context, messages, isLoading),
                  ),
                  // Voice Transcript
                  if (_isVoiceListening && _voiceTranscript.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final margin = screenWidth < 360 ? 12.0 : 16.0;
                        final padding = screenWidth < 360 ? 10.0 : 12.0;

                        return Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: margin,
                            vertical: 8,
                          ),
                          padding: EdgeInsets.all(padding),
                          decoration: BoxDecoration(
                            color: AppColors.geniePurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mic,
                                color: AppColors.geniePurple,
                                size: _getResponsiveIconSize(context, 20),
                              ),
                              SizedBox(width: screenWidth < 360 ? 6 : 8),
                              Expanded(
                                child: Text(
                                  _voiceTranscript,
                                  style: TextStyle(
                                    color: AppColors.geniePurple,
                                    fontSize: _getResponsiveFontSize(
                                      context,
                                      14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  // Limit Reached Message
                  if (shouldShowLimitBanner)
                    _buildLimitReachedBanner(
                      context,
                      aiChefLimit,
                      aiChefMessageCount,
                    ),
                  // Input Area
                  Builder(
                    builder: (context) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final outerPadding = screenWidth < 360 ? 6.0 : 8.0;
                      final innerPadding = screenWidth < 360 ? 8.0 : 12.0;
                      final buttonSize = screenWidth < 360 ? 28.0 : 32.0;
                      final iconSize = _getResponsiveIconSize(context, 20);

                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: outerPadding,
                          vertical: 4.0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: innerPadding,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).cardColor.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Camera Button
                                  GestureDetector(
                                    onTap: canSendMessage
                                        ? () => context.go('/scan')
                                        : null,
                                    child: Opacity(
                                      opacity: canSendMessage ? 1.0 : 0.4,
                                      child: Container(
                                        width: buttonSize,
                                        height: buttonSize,
                                        padding: EdgeInsets.all(
                                          buttonSize * 0.1,
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          color: AppColors.primary,
                                          size: iconSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Microphone Button
                                  GestureDetector(
                                    onTap: canSendMessage
                                        ? _toggleVoiceInput
                                        : null,
                                    child: Opacity(
                                      opacity: canSendMessage ? 1.0 : 0.4,
                                      child: Container(
                                        width: buttonSize,
                                        height: buttonSize,
                                        padding: EdgeInsets.all(
                                          buttonSize * 0.1,
                                        ),
                                        child: Icon(
                                          _isVoiceListening
                                              ? Icons.mic_off
                                              : Icons.mic,
                                          color: AppColors.primary,
                                          size: iconSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Text Input Field
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: TextField(
                                        controller: _messageController,
                                        enabled: canSendMessage,
                                        decoration: InputDecoration(
                                          hintText: context.t(
                                            'chat.placeholder',
                                          ),
                                          hintStyle: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(
                                                  canSendMessage ? 0.5 : 0.3,
                                                ),
                                            height: 3,
                                            fontSize: _getResponsiveFontSize(
                                              context,
                                              14,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          disabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: screenWidth < 360
                                                ? 12
                                                : 16,
                                            vertical: 4,
                                          ),
                                          isDense: true,
                                        ),
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(
                                                canSendMessage ? 1.0 : 0.5,
                                              ),
                                          fontSize: _getResponsiveFontSize(
                                            context,
                                            14,
                                          ),
                                        ),
                                        maxLines: 1,
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: canSendMessage
                                            ? (_) => _sendMessage()
                                            : null,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: screenWidth < 360 ? 6 : 8),
                                  // Send Button
                                  InkWell(
                                    onTap: (isLoading || !canSendMessage)
                                        ? null
                                        : _sendMessage,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Opacity(
                                      opacity: (isLoading || !canSendMessage)
                                          ? 0.4
                                          : 1.0,
                                      child: Container(
                                        width: buttonSize,
                                        height: buttonSize,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.gradientPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(
                                          buttonSize * 0.1875,
                                        ),
                                        child: Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: iconSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final padding = _getResponsivePadding(context);
    final spacing = _getResponsiveSpacing(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GenieMascot(
            size: screenWidth < 360 ? GenieMascotSize.md : GenieMascotSize.lg,
          ),
          SizedBox(height: padding),
          Text(
            context.t('chat.greeting'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.geniePink,
              fontSize: _getResponsiveFontSize(context, 24),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing),
          Text(
            context.t('chat.greeting.subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: _getResponsiveFontSize(context, 14),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: padding),
          // Suggestions
          _buildSuggestionChip(
            context,
            context.t('chat.suggestion1'),
            () => _handleSuggestion(context.t('chat.suggestion1')),
          ),
          SizedBox(height: spacing),
          _buildSuggestionChip(
            context,
            context.t('chat.suggestion2'),
            () => _handleSuggestion(context.t('chat.suggestion2')),
          ),
          SizedBox(height: spacing),
          _buildSuggestionChip(
            context,
            context.t('chat.suggestion3'),
            () => _handleSuggestion(context.t('chat.suggestion3')),
          ),
          SizedBox(height: spacing),
          _buildSuggestionChip(
            context,
            context.t('chat.suggestion4'),
            () => _handleSuggestion(context.t('chat.suggestion4')),
          ),
          SizedBox(height: padding),
          // Chat Native Ad (Small)
          const ScreenNativeAdWidget(
            screenKey: 'chat',
            size: CustomNativeAdSize.small,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(
    BuildContext context,
    String text,
    VoidCallback onTap,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360
        ? 16.0
        : (screenWidth < 400 ? 18.0 : 20.0);
    final verticalPadding = screenWidth < 360 ? 10.0 : 12.0;
    final iconSize = _getResponsiveIconSize(context, 16);
    final fontSize = _getResponsiveFontSize(context, 14);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: iconSize, color: AppColors.primary),
            SizedBox(width: screenWidth < 360 ? 6 : 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(
    BuildContext context,
    List<ChatMessage> messages,
    bool isLoading,
  ) {
    final padding = _getResponsivePadding(context);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(padding),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _buildTypingIndicator(context);
        }
        // Check if this is the last message and if it's an assistant message being streamed
        final isStreaming =
            isLoading &&
            index == messages.length - 1 &&
            !messages[index].isUser;
        return _buildMessageBubble(context, messages[index], isStreaming);
      },
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage message, [
    bool isStreaming = false,
  ]) {
    final isUser = message.isUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth < 360 ? 28.0 : 32.0;
    final avatarIconSize = _getResponsiveIconSize(context, 16);
    final messagePadding = screenWidth < 360 ? 10.0 : 12.0;
    final messageFontSize = _getResponsiveFontSize(context, 14);
    final maxWidthFactor = screenWidth < 360 ? 0.8 : 0.75;

    return Container(
      key: ValueKey('message_${message.id}'),
      margin: EdgeInsets.only(bottom: screenWidth < 360 ? 12 : 16),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: avatarIconSize,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            SizedBox(width: screenWidth < 360 ? 6 : 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(context, message),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * maxWidthFactor,
                ),
                padding: EdgeInsets.all(messagePadding),
                decoration: BoxDecoration(
                  gradient: isUser ? AppColors.gradientPrimary : null,
                  color: isUser ? null : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: isUser ? const Radius.circular(4) : null,
                    bottomLeft: !isUser ? const Radius.circular(4) : null,
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.8),
                          width: 1,
                        ),
                  boxShadow: isUser
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.15),
                            blurRadius: 24,
                            spreadRadius: -4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: isUser
                    ? SelectableText.rich(
                        TextSpan(
                          text: _getMessageContent(context, message.content),
                          style: TextStyle(
                            fontSize: messageFontSize,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : isStreaming
                    ? TypewriterText(
                        key: ValueKey('typewriter_${message.id}'),
                        text: message.content,
                        style: TextStyle(
                          fontSize: messageFontSize,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        speed: const Duration(milliseconds: 15),
                        animate: true,
                      )
                    : SelectableText(
                        _getMessageContent(context, message.content),
                        style: TextStyle(
                          fontSize: messageFontSize,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: screenWidth < 360 ? 6 : 8),
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: avatarIconSize,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMessageActions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(context.t('chat.copy')),
              onTap: () async {
                Navigator.pop(context);
                await Clipboard.setData(
                  ClipboardData(
                    text: _getMessageContent(context, message.content),
                  ),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('chat.message.copied')),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
            ),
            if (message.isUser)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(context.t('chat.edit')),
                onTap: () {
                  Navigator.pop(context);
                  final provider = context.read<ChatProvider>();
                  // Find the index of the message to edit
                  final messageIndex = provider.messages.indexWhere(
                    (m) => m.id == message.id,
                  );
                  if (messageIndex >= 0) {
                    // Remove this message and all messages after it (including assistant responses)
                    provider.messages.removeRange(
                      messageIndex,
                      provider.messages.length,
                    );
                    // Set the message content in the input field
                    _messageController.text = _getMessageContent(
                      context,
                      message.content,
                    );
                    // Focus the input field
                    FocusScope.of(context).requestFocus(FocusNode());
                  }
                },
              ),
            if (message.isUser)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.destructive),
                title: Text(
                  context.t('common.delete'),
                  style: const TextStyle(color: AppColors.destructive),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.read<ChatProvider>().removeMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth < 360 ? 28.0 : 32.0;
    final avatarIconSize = _getResponsiveIconSize(context, 16);
    final padding = screenWidth < 360 ? 10.0 : 12.0;
    final fontSize = _getResponsiveFontSize(context, 14);
    final indicatorSize = screenWidth < 360 ? 18.0 : 20.0;

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth < 360 ? 12 : 16),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              size: avatarIconSize,
              color: Colors.white,
            ),
          ),
          SizedBox(width: screenWidth < 360 ? 6 : 8),
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(
                20,
              ).copyWith(bottomLeft: const Radius.circular(4)),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.t('chat.thinking'),
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(width: screenWidth < 360 ? 6 : 8),
                SizedBox(
                  width: indicatorSize,
                  height: indicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedBanner(
    BuildContext context,
    int? limit,
    int messageCount,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalMargin = screenWidth < 360 ? 12.0 : 16.0;
    final padding = screenWidth < 360 ? 14.0 : 16.0;
    final iconSize = _getResponsiveIconSize(context, 24);
    final fontSize = _getResponsiveFontSize(context, 14);
    final titleFontSize = _getResponsiveFontSize(context, 16);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 8),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.geniePurple.withOpacity(0.15),
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: iconSize * 0.8,
                ),
              ),
              SizedBox(width: screenWidth < 360 ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('chat.limit.reached'),
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (limit != null) ...[
                      SizedBox(height: 4),
                      Text(
                        context.t('chat.limit.reached.message', {
                          'limit': limit.toString(),
                        }),
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ] else ...[
                      SizedBox(height: 4),
                      Text(
                        context.t('chat.ai.chef.disabled'),
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth < 360 ? 12 : 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Always allow opening the upgrade screen from a hard paywall.
                ProNavigation.tryOpen(
                  context,
                  replace: false,
                  // source: 'chat_limit',
                  // forceOpen: true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(
                  vertical: screenWidth < 360 ? 10 : 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ).copyWith(elevation: WidgetStateProperty.all(0)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  vertical: screenWidth < 360 ? 10 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: _getResponsiveIconSize(context, 18),
                    ),
                    SizedBox(width: 8),
                    Text(
                      context.t('common.upgrade'),
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
