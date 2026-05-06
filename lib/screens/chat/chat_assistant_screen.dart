import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs/app_dialogs.dart';
import '../../core/localization/l10n_extension.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../core/theme/colors.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/recipe.dart';
import '../../providers/chat_provider.dart';
import '../../providers/premium_provider.dart';
import '../../widgets/voice/voice_input_dialog.dart';
import '../../widgets/chat/typewriter_text.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/common/sticky_header.dart';

class ChatAssistantScreen extends StatefulWidget {
  final Recipe? initialRecipe;
  /// Changes whenever "Start cooking" is tapped (used to re-trigger prompt send).
  final String? cookLaunchId;

  const ChatAssistantScreen({super.key, this.initialRecipe, this.cookLaunchId});

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
  int _previousMessageCount = 0;
  bool _autoStartedFromRecipe = false;

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
    _trackCardScreenOpen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().ensureChatLoaded();
      _maybeAutoStartCookingFromRecipe();
    });
  }

  @override
  void didUpdateWidget(ChatAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldR = oldWidget.initialRecipe;
    final newR = widget.initialRecipe;
    final cookLaunchChanged = oldWidget.cookLaunchId != widget.cookLaunchId;
    final recipeIdentityChanged =
        (oldR?.slug ?? oldR?.id) != (newR?.slug ?? newR?.id) ||
        (oldR == null) != (newR == null);
    if (newR != null && (recipeIdentityChanged || cookLaunchChanged)) {
      _autoStartedFromRecipe = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeAutoStartCookingFromRecipe();
      });
    }
  }

  /// Track when card screen is opened (ads removed - reserved for future ad plan)
  Future<void> _trackCardScreenOpen() async {}

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  String _buildCookingPromptFromRecipe(BuildContext context, Recipe recipe) {
    final ingredients = recipe.ingredients
        .take(24)
        .map((i) => '- ${i.quantity} ${i.unit} ${i.name}'.trim())
        .join('\n');
    final steps = recipe.instructions
        .take(20)
        .map((s) => '${s.step}. ${s.text}')
        .join('\n');

    return [
      'I want to cook "${recipe.title}".',
      'Please guide me step-by-step like an AI chef.',
      'Ingredients:\n$ingredients',
      'Instructions:\n$steps',
      'Start with step 1 and wait for my confirmation before moving on.',
    ].join('\n\n');
  }

  Future<void> _maybeAutoStartCookingFromRecipe() async {
    if (_autoStartedFromRecipe) return;
    final recipe = widget.initialRecipe;
    if (recipe == null) return;

    final premiumProvider = Provider.of<PremiumProvider>(
      context,
      listen: false,
    );
    if (!premiumProvider.isPremium && !premiumProvider.canSendAiChefMessage()) {
      // User hit free limit — don't auto-send anything.
      return;
    }

    final prompt = _buildCookingPromptFromRecipe(context, recipe);
    _autoStartedFromRecipe = true;
    await _proceedWithMessage(prompt);
  }

  Future<void> _showChatResetInterThenStartNewChat(
    BuildContext context,
    ChatProvider chatProvider,
  ) async {
    void doStartNewChat() {
      if (!context.mounted) return;
      chatProvider.startNewChat();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('chat.new.chat')),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    try {
      await RemoteConfigService.initialize();
      await RemoteConfigService.fetchAndActivate();
    } catch (_) {}

    final shouldShowAd = Platform.isIOS
        ? RemoteConfigService.chatResetInterIos
        : RemoteConfigService.chatResetInter;

    if (shouldShowAd && context.mounted) {
      try {
        await AdService.showInterstitialAdForType(
          adType: 'chatReset',
          context: context,
          loadAdFunction: () => AdService.loadChatResetInterstitialAd(),
          onAdDismissed: doStartNewChat,
          onAdFailedToShow: (_) => doStartNewChat(),
        );
        return;
      } catch (_) {}
    }

    doStartNewChat();
  }

  Future<void> _showVoiceInputDialog() async {
    final text = await showVoiceInputDialog(context);
    if (text != null && text.trim().isNotEmpty && mounted) {
      setState(() {
        _messageController.text = text.trim();
      });
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

    // Determine if limit banner should be shown (sub_aichat: off/0=unlimited)
    // Show banner only when there is a limit AND user has reached it
    final shouldShowLimitBanner =
        !premiumProvider.isPremium &&
        aiChefLimit != null &&
        aiChefMessageCount >= aiChefLimit;

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
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (mounted) context.go('/');
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
                    titleStyle: StickyHeader.shellTabTitleStyle(context),
                    showBack: false,
                    onBack: null,
                    backgroundColor: Colors.transparent,
                    statusBarColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1F35)
                        : AppColors.genieBlush,
                    rightContent: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Message counter for free users (e.g. 2/5)
                        if (!premiumProvider.isPremium &&
                            aiChefLimit != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '$aiChefMessageCount/$aiChefLimit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          icon: const Icon(Icons.history),
                          onPressed: () => context.go('/chat-history'),
                          tooltip: context.t('chatHistory.title'),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: canSendMessage
                                ? null
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          onPressed: () async {
                            if (!canSendMessage) {
                              _showChatLimitSheet(context, aiChefLimit);
                              return;
                            }
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  ctx.t('chat.new.chat.confirm.title'),
                                ),
                                content: Text(
                                  ctx.t('chat.new.chat.confirm.message'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(ctx.t('common.cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(ctx.t('common.confirm')),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              await _showChatResetInterThenStartNewChat(
                                context,
                                chatProvider,
                              );
                            }
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
                                        ? () => context.push('/scan-camera')
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
                                        ? _showVoiceInputDialog
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
                                          Icons.mic,
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
    // Only show separate typing row when waiting for first AI response (last msg is user)
    // When we have an assistant message (empty or not), show typing inside that bubble only
    final showTypingRow =
        isLoading && (messages.isEmpty || messages.last.isUser);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(padding),
      itemCount: messages.length + (showTypingRow ? 1 : 0),
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
                    ? (message.content.isEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.t('chat.thinking'),
                                  style: TextStyle(
                                    fontSize: messageFontSize,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(width: screenWidth < 360 ? 6 : 8),
                                SizedBox(
                                  width: screenWidth < 360 ? 18 : 20,
                                  height: screenWidth < 360 ? 18 : 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : TypewriterText(
                              key: ValueKey('typewriter_${message.id}'),
                              text: message.content,
                              style: TextStyle(
                                fontSize: messageFontSize,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              speed: const Duration(milliseconds: 15),
                              animate: false,
                            ))
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

  void _showChatLimitSheet(BuildContext context, int? limit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                ctx.t('chat.limit.reached'),
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                limit != null
                    ? ctx.t('chat.limit.reached.message', {
                        'limit': limit.toString(),
                      })
                    : ctx.t('chat.ai.chef.disabled'),
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ProNavigation.tryOpen(context, replace: false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(ctx.t('common.upgrade')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.t('common.cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
