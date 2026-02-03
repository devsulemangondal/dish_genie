import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/chat_message.dart';
import 'supabase_service.dart';

class ChatService {
  /// Stream chat responses token-by-token using Supabase chat-assistant function
  static Stream<String> streamChat(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
  }) async* {
    // Check if Supabase is initialized
    if (!SupabaseService.isInitialized) {
      throw Exception(
        'Supabase is not initialized. Please ensure Supabase credentials are configured.',
      );
    }

    // Get Supabase URL and key
    final supabaseUrl = SupabaseService.url;
    final supabaseKey = SupabaseService.anonKey;

    if (supabaseUrl == null || supabaseKey == null) {
      throw Exception('Supabase credentials are not configured');
    }

    // Use chat-assistant function (matching web app)
    final functionUrl = '$supabaseUrl/functions/v1/chat-assistant';

    final request = http.Request('POST', Uri.parse(functionUrl));
    // Match web app exactly: only Authorization header (no apikey)
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $supabaseKey',
    });

    // Convert messages to the format expected by the API (matching web app format)
    final messagesPayload = messages
        .map(
          (msg) => {
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.content,
          },
        )
        .toList();

    // Match web app exactly: include messages and context (even if null)
    final requestBody = <String, dynamic>{'messages': messagesPayload};
    if (context != null) {
      requestBody['context'] = context;
    }
    request.body = json.encode(requestBody);

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      try {
        final errorJson = json.decode(body) as Map<String, dynamic>;
        final error = errorJson['error'] ?? 'Request failed';
        throw Exception(error);
      } catch (e) {
        throw Exception('Request failed: ${response.statusCode}');
      }
    }

    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;

      while (buffer.contains('\n')) {
        final newlineIndex = buffer.indexOf('\n');
        String line = buffer.substring(0, newlineIndex);
        buffer = buffer.substring(newlineIndex + 1);

        if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
        if (line.startsWith(':') || line.trim().isEmpty) continue;
        if (!line.startsWith('data: ')) continue;

        final jsonStr = line.substring(6).trim();
        if (jsonStr == '[DONE]') return;

        try {
          final parsed = json.decode(jsonStr) as Map<String, dynamic>;
          final content =
              parsed['choices']?[0]?['delta']?['content'] as String?;
          if (content != null) yield content;
        } catch (_) {
          buffer = '$line\n$buffer';
          break;
        }
      }
    }
  }

  // Send message to chat assistant with streaming support
  // This method is kept for backward compatibility with ChatProvider
  static Stream<String> sendMessageStream({
    required List<ChatMessage> messages,
    Map<String, dynamic>? context,
  }) async* {
    // Use the new streamChat method with context (matching web app)
    await for (final chunk in streamChat(messages, context: context)) {
      yield chunk;
    }
  }

  // Legacy method for backward compatibility (non-streaming)
  // Note: This uses Supabase functions for consistency
  static Future<String?> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    try {
      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        return null;
      }

      // Get Supabase URL and key
      final supabaseUrl = SupabaseService.url;
      final supabaseKey = SupabaseService.anonKey;

      if (supabaseUrl == null || supabaseKey == null) {
        return null;
      }

      final url = Uri.parse('$supabaseUrl/functions/v1/chat-assistant');
      // Match web app exactly: only Authorization header (no apikey)
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
        },
        body: json.encode({
          'messages': [
            {'role': 'user', 'content': message},
          ],
          if (conversationId != null) 'conversation_id': conversationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;
        return data?['response'] as String?;
      }
      return null;
    } catch (e) {
      print('Error sending chat message: $e');
      return null;
    }
  }

  // Get chat history (from local storage or Supabase)
  static Future<List<ChatConversation>> getChatHistory() async {
    // TODO: Implement with Supabase table if available
    // For now, return empty list
    return [];
  }

  // Save conversation
  static Future<void> saveConversation(ChatConversation conversation) async {
    // TODO: Implement with Supabase table if available
  }
}
