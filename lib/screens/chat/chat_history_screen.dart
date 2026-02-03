import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../providers/chat_provider.dart';
import '../../data/models/chat_message.dart';
import '../../services/storage_service.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatConversation> _conversations = [];
  List<ChatConversation> _filteredConversations = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterConversations();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh conversations when screen becomes visible again
    // This ensures the list is up-to-date when returning from chat screen
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    
    // Load from storage - use getChatConversations() to get all saved chats
    try {
      final conversationsData = await StorageService.getChatConversations();
      _conversations = conversationsData
          .map((json) => ChatConversation.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading chat history: $e');
    }

    setState(() {
      _isLoading = false;
      _filterConversations();
    });
  }

  void _filterConversations() {
    if (_searchQuery.isEmpty) {
      _filteredConversations = _conversations;
    } else {
      _filteredConversations = _conversations.where((conv) {
        return conv.title.toLowerCase().contains(_searchQuery) ||
            conv.messages.any((msg) =>
                msg.content.toLowerCase().contains(_searchQuery));
      }).toList();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return context.t('chatHistory.today');
    } else if (dateOnly == yesterday) {
      return context.t('chatHistory.yesterday');
    } else {
      final diff = now.difference(date).inDays;
      if (diff < 7) {
        return '${diff} ${context.t('chatHistory.daysAgo')}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }

  Future<void> _deleteConversation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('chatHistory.deleteConfirmTitle')),
        content: Text(context.t('chatHistory.deleteConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _conversations.removeWhere((conv) => conv.id == id);
        _filterConversations();
      });
      
      await _saveConversations();
      
      // Also delete from ChatProvider
      context.read<ChatProvider>().deleteConversation(id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('chatHistory.deleted')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _clearAllConversations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('chatHistory.clearAllTitle')),
        content: Text(context.t('chatHistory.clearAllMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _conversations.clear();
        _filteredConversations.clear();
      });
      
      await _saveConversations();
      
      // Also clear from ChatProvider
      context.read<ChatProvider>().clearAllConversations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('chatHistory.allCleared')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _saveConversations() async {
    try {
      final conversationsJson = _conversations.map((c) => c.toJson()).toList();
      await StorageService.saveChatConversations(conversationsJson);
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  void _handleBack() {
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        // If we can't pop, navigate to chat screen
        context.go('/chat');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
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
            Column(
              children: [
                StickyHeader(
                  title: context.t('chatHistory.title'),
                  onBack: _handleBack,
                backgroundColor: Colors.transparent,
                statusBarColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1F35)
                    : AppColors.genieBlush,
                rightContent: _conversations.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _clearAllConversations,
                        tooltip: context.t('chatHistory.clearAll'),
                      )
                    : null,
              ),
              // Search Bar
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.t('chatHistory.searchPlaceholder'),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredConversations.isEmpty
                        ? _buildEmptyState(context)
                        : _buildConversationsList(context),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? context.t('chatHistory.noResults')
                  : context.t('chatHistory.empty'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? context.t('chatHistory.tryDifferent')
                  : context.t('chatHistory.emptyHint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.go('/chat');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(context.t('chatHistory.startChatting')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredConversations.length,
      itemBuilder: (context, index) {
        final conversation = _filteredConversations[index];
        return _buildConversationCard(context, conversation);
      },
    );
  }

  Widget _buildConversationCard(
      BuildContext context, ChatConversation conversation) {
    final lastMessage = conversation.messages.isNotEmpty
        ? conversation.messages.last
        : null;
    final messageCount = conversation.messages.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent, // Transparent is theme-agnostic
        child: InkWell(
          onTap: () async {
            // Load conversation and navigate to chat
            await context.read<ChatProvider>().loadConversation(conversation.id);
            if (mounted) {
              context.go('/chat');
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (lastMessage != null)
                        Text(
                          lastMessage.content,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          context.t('chatHistory.noMessages'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                    ],
                  ),
                ),
                // Metadata
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(conversation.updatedAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (messageCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$messageCount ${context.t('chatHistory.messages')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteConversation(conversation.id),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
