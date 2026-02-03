class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? conversationId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.conversationId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'is_user': isUser,
        'timestamp': timestamp.toIso8601String(),
        if (conversationId != null) 'conversation_id': conversationId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        content: json['content'] as String,
        isUser: json['is_user'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        conversationId: json['conversation_id'] as String?,
      );
}

class ChatConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  // Getter for compatibility with web app format (name)
  String get name => title;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'name': title, // Also include 'name' for web app compatibility
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'createdAt': createdAt.millisecondsSinceEpoch, // Web app format
        'updatedAt': updatedAt.millisecondsSinceEpoch, // Web app format
        'messages': messages.map((e) => e.toJson()).toList(),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    // Handle both 'name' (web app) and 'title' (Flutter) fields
    final title = json['name'] as String? ?? json['title'] as String? ?? 'New Chat';
    
    // Handle both timestamp formats: milliseconds (web app) and ISO string (Flutter)
    DateTime createdAt;
    DateTime updatedAt;
    
    if (json['createdAt'] != null) {
      // Web app format: milliseconds since epoch
      createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int);
    } else if (json['created_at'] != null) {
      // Flutter format: ISO string
      createdAt = DateTime.parse(json['created_at'] as String);
    } else {
      createdAt = DateTime.now();
    }
    
    if (json['updatedAt'] != null) {
      // Web app format: milliseconds since epoch
      updatedAt = DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int);
    } else if (json['updated_at'] != null) {
      // Flutter format: ISO string
      updatedAt = DateTime.parse(json['updated_at'] as String);
    } else {
      updatedAt = DateTime.now();
    }
    
    // Handle messages - web app uses 'role' field, Flutter uses 'is_user'
    final messagesList = json['messages'] as List<dynamic>? ?? [];
    final messages = messagesList.map((e) {
      final msgData = e as Map<String, dynamic>;
      // Handle both web app format (role) and Flutter format (is_user)
      if (msgData.containsKey('role')) {
        // Web app format: { id, role: 'user'|'assistant', content, timestamp }
        return ChatMessage(
          id: msgData['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          content: msgData['content'] as String? ?? '',
          isUser: msgData['role'] == 'user',
          timestamp: msgData['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(msgData['timestamp'] as int)
              : DateTime.now(),
          conversationId: json['id'] as String?,
        );
      } else {
        // Flutter format: use fromJson
        return ChatMessage.fromJson(msgData);
      }
    }).toList();
    
    return ChatConversation(
      id: json['id'] as String,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: messages,
    );
  }
}
