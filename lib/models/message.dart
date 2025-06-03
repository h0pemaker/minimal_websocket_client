enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

enum MessageType {
  statusUpdate,
  readUpdate,
}

MessageStatus? parseStatus(String? status) {
  switch (status) {
    case 'PENDING':
      return MessageStatus.pending;
    case 'SENT':
      return MessageStatus.sent;
    case 'DELIVERED':
      return MessageStatus.delivered;
    case 'READ':
      return MessageStatus.read;
    case 'FAILED':
      return MessageStatus.failed;
    default:
      return null;
  }
}

MessageType? parseType(String? type) {
  switch (type) {
    case 'STATUS_UPDATE':
      return MessageType.statusUpdate;
    case 'READ_UPDATE':
      return MessageType.readUpdate;
    default:
      return null;
  }
}

class Message {
  final String? id;
  final String chatroomId;
  final String senderId;
  final String? recipientId;
  final String content;
  final DateTime? timestamp;
  final String? imageUrl;
  final MessageStatus? status;
  final MessageType? type;
  final DateTime? readOn;

  Message({
    this.id,
    required this.chatroomId,
    required this.senderId,
    this.recipientId,
    required this.content,
    this.timestamp,
    this.imageUrl,
    this.status,
    this.type,
    this.readOn
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      chatroomId: json['chatroomId'] ?? '',
      senderId: json['senderId'] ?? '',
      recipientId: json['recipientId'],
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      imageUrl: json['imageUrl'],
      status: parseStatus(json['status']),
      type: parseType(json['type']),
      readOn: json['readOn'] != null ? DateTime.parse(json['readOn']) : null,
    );
  }

  Message copyWith({
    String? id,
    String? tempId,
    String? chatroomId,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    String? imageUrl,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      chatroomId: chatroomId ?? this.chatroomId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
    );
  }
}

extension MessageExtension on Message {
  bool get contentIsImageUrl {
    final url = content.toLowerCase();
    return url.startsWith('http') &&
        (url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png') || url.endsWith('.gif'));
  }
} 