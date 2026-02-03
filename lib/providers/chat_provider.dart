import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _conversationId;
  List<ChatConversation> _conversations = [];

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get conversationId => _conversationId;
  List<ChatConversation> get conversations => _conversations;

  ChatProvider() {
    _loadLastActiveChat();
    _loadConversations();
  }

  // Load last active chat (matching web app behavior)
  Future<void> _loadLastActiveChat() async {
    try {
      // Try to load from chat history (last active chat)
      final chatHistoryJson = await StorageService.getChatHistory();
      if (chatHistoryJson != null) {
        final chatHistory =
            json.decode(chatHistoryJson) as Map<String, dynamic>?;
        if (chatHistory != null) {
          final messagesList = chatHistory['messages'] as List<dynamic>?;
          final chatId = chatHistory['chatId'] as String?;

          if (messagesList != null && messagesList.isNotEmpty) {
            _messages = messagesList.map((e) {
              final msgData = e as Map<String, dynamic>;
              // Handle both web app format (role) and Flutter format (is_user)
              if (msgData.containsKey('role')) {
                // Web app format: { id, role: 'user'|'assistant', content, timestamp }
                return ChatMessage(
                  id:
                      msgData['id'] as String? ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  content: msgData['content'] as String? ?? '',
                  isUser: msgData['role'] == 'user',
                  timestamp: msgData['timestamp'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          msgData['timestamp'] as int,
                        )
                      : DateTime.now(),
                  conversationId: chatId,
                );
              } else {
                // Flutter format: use fromJson
                return ChatMessage.fromJson(msgData);
              }
            }).toList();
            _conversationId = chatId;
            notifyListeners();
            return;
          }
        }
      }

      // Fallback: Load from conversations if no active chat
      if (_conversationId != null) {
        await _loadMessages();
      }
    } catch (e) {
      print('Error loading last active chat: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId != null) {
      // Load messages for current conversation
      final conversations = await StorageService.getChatConversations();
      final conversation = conversations.firstWhere(
        (c) => c['id'] == _conversationId,
        orElse: () => {},
      );

      if (conversation.isNotEmpty && conversation['messages'] != null) {
        final messagesList = conversation['messages'] as List<dynamic>;
        _messages = messagesList.map((e) {
          final msgData = e as Map<String, dynamic>;
          // Handle both web app format (role) and Flutter format (is_user)
          if (msgData.containsKey('role')) {
            // Web app format: { id, role: 'user'|'assistant', content, timestamp }
            return ChatMessage(
              id:
                  msgData['id'] as String? ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              content: msgData['content'] as String? ?? '',
              isUser: msgData['role'] == 'user',
              timestamp: msgData['timestamp'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      msgData['timestamp'] as int,
                    )
                  : DateTime.now(),
              conversationId: _conversationId,
            );
          } else {
            // Flutter format: use fromJson
            return ChatMessage.fromJson(msgData);
          }
        }).toList();
        notifyListeners();
      }
    }
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await StorageService.getChatConversations();
      _conversations = conversations
          .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading conversations: $e');
    }
  }

  Future<void> _saveConversation() async {
    if (_conversationId == null || _messages.isEmpty) return;

    try {
      final conversations = await StorageService.getChatConversations();

      // Find first user message for name generation (matching web app)
      final firstUserMessage = _messages.firstWhere(
        (m) => m.isUser,
        orElse: () => _messages.first,
      );

      // Generate chat name (matching web app logic)
      String chatName = 'New Chat';
      if (firstUserMessage.content.isNotEmpty) {
        // Truncate to first 40 chars or first sentence
        final firstSentence = firstUserMessage.content.split(
          RegExp(r'[.!?]'),
        )[0];
        final truncated = firstSentence.length > 40
            ? firstSentence.substring(0, 40)
            : firstSentence;
        chatName =
            truncated + (firstUserMessage.content.length > 40 ? '...' : '');
      }

      // Update or add conversation (matching web app format)
      final index = conversations.indexWhere((c) => c['id'] == _conversationId);
      final conversationData = {
        'id': _conversationId,
        'name': chatName, // Match web app: 'name' instead of 'title'
        'messages': _messages
            .map(
              (m) => {
                'id': m.id,
                'role': m.isUser ? 'user' : 'assistant', // Match web app format
                'content': m.content,
                'timestamp': m
                    .timestamp
                    .millisecondsSinceEpoch, // Match web app: milliseconds
              },
            )
            .toList(),
        'createdAt': index >= 0
            ? conversations[index]['createdAt']
            : DateTime.now()
                  .millisecondsSinceEpoch, // Match web app: milliseconds
        'updatedAt': DateTime.now()
            .millisecondsSinceEpoch, // Match web app: milliseconds
      };

      if (index >= 0) {
        conversations[index] = conversationData;
      } else {
        conversations.add(conversationData);
      }

      await StorageService.saveChatConversations(conversations);

      // Also save as last active chat (matching web app behavior)
      await StorageService.saveChatHistory(
        json.encode({
          'messages': _messages.map((m) => m.toJson()).toList(),
          'chatId': _conversationId,
        }),
      );

      await _loadConversations();
    } catch (e) {
      print('Error saving conversation: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    // Create conversation ID if new chat
    if (_conversationId == null) {
      _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      conversationId: _conversationId,
    );

    _messages.add(userMessage);
    _isLoading = true;
    notifyListeners();

    try {
      // Generate assistant message ID (but don't create empty message yet)
      final assistantId = DateTime.now().millisecondsSinceEpoch.toString();

      // Stream the response
      String fullResponse = '';
      // Get all messages for streaming (including the new user message)
      final messagesForStream = List<ChatMessage>.from(_messages);

      bool isFirstChunk = true;
      
      try {
        await for (final chunk in ChatService.sendMessageStream(
          messages: messagesForStream,
        )) {
          fullResponse += chunk;
          
          // Create assistant message on first chunk only
          if (isFirstChunk && fullResponse.isNotEmpty) {
            isFirstChunk = false;
            final assistantMessage = ChatMessage(
              id: assistantId,
              content: fullResponse,
              isUser: false,
              timestamp: DateTime.now(),
              conversationId: _conversationId,
            );
            _messages.add(assistantMessage);
            _isLoading = false; // Hide typing indicator once we have content
            notifyListeners();
          } else if (!isFirstChunk && fullResponse.isNotEmpty) {
            // Update the assistant message with accumulated content
            final index = _messages.indexWhere((m) => m.id == assistantId);
            if (index >= 0) {
              _messages[index] = ChatMessage(
                id: assistantId,
                content: fullResponse,
                isUser: false,
                timestamp: _messages[index].timestamp,
                conversationId: _conversationId,
              );
              notifyListeners();
            }
          }
        }

        // If no response was received, ensure loading is false
        if (fullResponse.isEmpty) {
          _isLoading = false;
        }
      } catch (streamError) {
        // Ensure loading is false on error
        _isLoading = false;
        // Re-throw to be caught by outer catch block
        rethrow;
      }

      // Save conversation after receiving response
      await _saveConversation();

      // Notify listeners one final time to ensure UI is updated
      notifyListeners();
    } catch (e) {
      print('Error sending message: $e');
      // Remove the assistant message if there was an error (match web app behavior)
      _messages.removeWhere((m) => !m.isUser && m.content.isEmpty);

      // Check if it's a configuration error
      // Store error keys that will be translated in the UI
      final errorString = e.toString().toLowerCase();
      String errorKey;

      if (errorString.contains('not configured') ||
          errorString.contains('supabase_url') ||
          errorString.contains('supabase_anon_key')) {
        errorKey = 'chat.error.not.configured';
      } else if (errorString.contains('rate limit')) {
        errorKey = 'chat.error.rate.limit';
      } else {
        errorKey = 'chat.error.generic';
      }

      // Match web app: replace last message with error message
      // Store the error key with a special prefix so UI can identify and translate it
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '__L10N_KEY__:$errorKey',
        isUser: false,
        timestamp: DateTime.now(),
        conversationId: _conversationId,
      );
      _messages.add(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _messages.clear();
    _conversationId = null;
    // Clear last active chat (matching web app)
    StorageService.saveChatHistory(
      json.encode({'messages': [], 'chatId': null}),
    );
    notifyListeners();
  }

  void startNewChat() {
    // Save current chat before starting new one (matching web app)
    if (_messages.isNotEmpty) {
      _saveConversation();
    }
    _messages.clear();
    _conversationId = null;
    // Clear last active chat (matching web app)
    StorageService.saveChatHistory(
      json.encode({'messages': [], 'chatId': null}),
    );
    notifyListeners();
  }

  void removeMessage(ChatMessage message) {
    final messageIndex = _messages.indexWhere((m) => m.id == message.id);
    if (messageIndex >= 0) {
      _messages.removeAt(messageIndex);
      // If removing a user message, also remove the assistant response that follows
      if (message.isUser &&
          messageIndex < _messages.length &&
          !_messages[messageIndex].isUser) {
        _messages.removeAt(messageIndex);
      }
    }
    _saveConversation();
    notifyListeners();
  }

  Future<void> loadConversation(String conversationId) async {
    try {
      _conversationId = conversationId;
      await _loadMessages();
    } catch (e) {
      print('Error loading conversation: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      final conversations = await StorageService.getChatConversations();
      conversations.removeWhere((c) => c['id'] == conversationId);
      await StorageService.saveChatConversations(conversations);

      if (_conversationId == conversationId) {
        startNewChat();
      }

      await _loadConversations();
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }

  Future<void> renameConversation(
    String conversationId,
    String newTitle,
  ) async {
    try {
      final conversations = await StorageService.getChatConversations();
      final index = conversations.indexWhere((c) => c['id'] == conversationId);
      if (index >= 0) {
        conversations[index]['title'] = newTitle;
        conversations[index]['updated_at'] = DateTime.now().toIso8601String();
        await StorageService.saveChatConversations(conversations);
        await _loadConversations();
      }
    } catch (e) {
      print('Error renaming conversation: $e');
    }
  }

  Future<void> clearAllConversations() async {
    try {
      await StorageService.clearChatHistory();
      _conversations.clear();
      startNewChat();
      notifyListeners();
    } catch (e) {
      print('Error clearing all conversations: $e');
    }
  }
}
