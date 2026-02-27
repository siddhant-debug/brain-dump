import 'dart:convert';
import 'dart:developer' as developer;

enum MessageSender { user, ai, system }

enum MessageStatus { sending, sent, error, thinking, memorizing, memorized }

class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;

  final List<String> sources;
  final bool isRestored; // Flag to indicate if message is restored from history
  final Map<String, dynamic>? locationContext;

  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.sources = const [],
    this.isRestored = false,
    this.locationContext,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageSender? sender,
    DateTime? timestamp,
    MessageStatus? status,
    List<String>? sources,
    bool? isRestored,
    Map<String, dynamic>? locationContext,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      sources: sources ?? this.sources,
      isRestored: isRestored ?? this.isRestored,
      locationContext: locationContext ?? this.locationContext,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<String> parsedSources = [];

    // 1. Handle History API (JSON String)
    if (json['context_sources'] != null && json['context_sources'] is String) {
      try {
        final List<dynamic> decoded = jsonDecode(json['context_sources']);
        parsedSources = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        developer.log('Error parsing context_sources: $e', name: 'ChatMessage');
      }
    } else if (json['sources'] != null) {
      // From Stream or direct map (List)
      parsedSources = List<String>.from(json['sources']);
    }

    return ChatMessage(
      id: json['id'].toString(),
      content: json['content'],
      sender: json['sender'] == 'user' ? MessageSender.user : MessageSender.ai,
      timestamp: DateTime.parse(json['timestamp']),
      status: MessageStatus.sent,
      sources: parsedSources,
      isRestored: true, // Messages from JSON (history) are always restored
      locationContext: json['location_context'] != null
          ? Map<String, dynamic>.from(json['location_context'])
          : null,
    );
  }
}
