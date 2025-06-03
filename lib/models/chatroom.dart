class Chatroom {
  final String id;

  Chatroom({required this.id});

  factory Chatroom.fromJson(Map<String, dynamic> json) {
    return Chatroom(id: json['id'] ?? json['_id'] ?? '');
  }
}
