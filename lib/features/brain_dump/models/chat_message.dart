enum MessageSender { user, ai, system }

enum MessageStatus { sending, sent, error, thinking, memorizing, memorized }

class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  ChatMessage copyWith({String? content, MessageStatus? status}) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      sender: sender,
      timestamp: timestamp,
      status: status ?? this.status,
    );
  }
}
