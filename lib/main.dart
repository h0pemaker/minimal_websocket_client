import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  runApp(MyApp());
}

class Chatroom {
  final String id;

  Chatroom({required this.id});

  factory Chatroom.fromJson(Map<String, dynamic> json) {
    return Chatroom(id: json['id'] ?? json['_id'] ?? '');
  }
}

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

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StompClient? stompClient;
  String? currentUserId;
  List<Chatroom> chatrooms = [];
  Chatroom? selectedChatroom;
  List<Message> messages = [];
  int? currentSeqId;
  final TextEditingController messageController = TextEditingController();

  @override
  void dispose() {
    stompClient?.deactivate();
    messageController.dispose();
    super.dispose();
  }

  Future<void> fetchChatrooms() async {
    if (currentUserId == null) return;

    final url = 'http://10.0.2.2:3000/api/chatrooms/user/$currentUserId/chatrooms';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> chatroomListJson = jsonDecode(response.body);
        setState(() {
          chatrooms = chatroomListJson.map((json) => Chatroom.fromJson(json)).toList();
        });
      } else {
        print('Failed to fetch chatrooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching chatrooms: $e');
    }
  }

  void connectWebSocket() {
    if (currentUserId == null) return;

    final websocketUrl = 'ws://10.0.2.2:3000/ws?userId=$currentUserId';

    stompClient = StompClient(
      config: StompConfig(
        url: websocketUrl,
        onConnect: onConnect,
        onStompError: (frame) => print('STOMP Error: ${frame.body}'),
        onWebSocketError: (error) => print('WebSocket Error: $error'),
        onDisconnect: (frame) => print('Disconnected'),
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    stompClient!.activate();
  }

  void onConnect(StompFrame frame) {
    print('Connected to STOMP WebSocket');

    stompClient?.subscribe(
      destination: '/user/queue/messages',
      callback: (frame) {
        final msgBody = frame.body ?? '';
        final messageId = extractMessageId(msgBody);
        sendAck(messageId);

        try {
          final decodedJson = jsonDecode(msgBody);
          final message = Message.fromJson(decodedJson);
          setState(() {
            final index = messages.indexWhere((msg) =>
            msg.timestamp?.millisecondsSinceEpoch == message.timestamp?.millisecondsSinceEpoch && msg.senderId == message.senderId);
            print("user id : ${currentUserId??""}");
            print("type : ${message.type??""}");
            print("message : $decodedJson");
            if (index != -1) {
              messages[index] = message;
            } else {
              messages.add(message);
            }
          });
        } catch (e) {
          print('Error decoding message JSON: $e');
        }
      },
    );
  }

  String extractMessageId(String? body) {
    if (body == null || body.isEmpty) return '';
    try {
      final jsonData = jsonDecode(body);
      // Your server might send messageId or id - adjust accordingly
      return jsonData['id'] ?? jsonData['messageId'] ?? '';
    } catch (e) {
      print('Error parsing message body: $e');
      return '';
    }
  }

  void sendAck(String messageId) {
    if (messageId.isEmpty) return;
    final ackPayload = jsonEncode({'messageId': messageId});
    stompClient?.send(destination: '/app/acknowledge', body: ackPayload);
    print('Sent ack for messageId: $messageId');
  }

  void sendMessage() {
    if (selectedChatroom == null || currentUserId == null) return;

    final chatroomId = selectedChatroom!.id;
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();

    final messagePayload = jsonEncode({
      'senderId': currentUserId,
      'chatroomId': chatroomId,
      'content': text,
      'timestamp': now.toIso8601String(),
    });

    stompClient?.send(
      destination: '/app/chat.sendMessage/$chatroomId',
      body: messagePayload,
    );

    // Add local message with status "PENDING"
    setState(() {
      messages.add(
        Message(
          chatroomId: chatroomId,
          senderId: currentUserId!,
          content: text,
          timestamp: now,
          status: MessageStatus.pending,
        ),
      );
      messageController.clear();
    });
  }

  void sendReadUpdate(Message message) {
    String? messageId = message.id;
    String chatroomId = message.chatroomId;
    if (messageId == null || messageId.isEmpty || stompClient == null) return;

    print("read update sent");
    print("userId : $currentUserId "+"messageId : $messageId "+"chatroomId : $chatroomId");

    final payload = jsonEncode({
      'messageId': messageId,
      'chatroomId': chatroomId,
    });

    stompClient?.send(destination: '/app/chat.readUpdate', body: payload);
  }

  Future<void> launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(url);
    } else {
      print('Could not launch $url');
    }
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return Icons.hourglass_bottom;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return Colors.grey;
      case MessageStatus.sent:
        return Colors.black;
      case MessageStatus.delivered:
        return Colors.black;
      case MessageStatus.read:
        return Colors.blue;
      case MessageStatus.failed:
        return Colors.red;
    }
  }

  Widget buildUserIdInputScreen() {
    final TextEditingController userIdController = TextEditingController();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Enter your User ID to start', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final enteredId = userIdController.text.trim();
                if (enteredId.isNotEmpty) {
                  setState(() {
                    currentUserId = enteredId;
                  });
                  fetchChatrooms();
                  connectWebSocket();
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChatroomList() {
    if (chatrooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: chatrooms.length,
      itemBuilder: (context, index) {
        final chatroom = chatrooms[index];
        return ListTile(
          title: Text('Chatroom: ${chatroom.id}'),
          onTap: () {
            setState(() {
              selectedChatroom = chatroom;
              messages.clear();
            });
          },
        );
      },
    );
  }

  Widget buildChatScreen() {
    return Column(
      children: [
        ListTile(
          title: Text('Chatroom ID: ${selectedChatroom!.id}'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                selectedChatroom = null;
                messages.clear();
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isMine = message.senderId == currentUserId;

              return VisibilityDetector(
                key: Key("visibility_detector-${message.id}"),
                onVisibilityChanged: (VisibilityInfo info) {
                  if (info.visibleFraction > 0.7 && message.status!=MessageStatus.read && !isMine) {
                    sendReadUpdate(message);
                  }
                },
                child: Align(
                  alignment: !isMine ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.blue[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    child: Column(
                      crossAxisAlignment: !isMine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                      children: [
                        if (message.contentIsImageUrl)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Image.network(
                              message.content,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                        message.contentIsImageUrl
                            ? GestureDetector(
                          onTap: () => launchUrl(message.content),
                          child: Text(
                            message.content,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                            : Text(message.content),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.timestamp?.toLocal().toString().split('.')[0] ?? '',
                              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                            ),
                            if (isMine && message.status != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                _getStatusIcon(message.status!),
                                size: 14,
                                color: _getStatusColor(message.status!),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Enter message',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: sendMessage,
              ),
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter STOMP Chat Client',
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter STOMP Chat Client')),
        body: currentUserId == null
            ? buildUserIdInputScreen()
            : selectedChatroom == null
            ? buildChatroomList()
            : buildChatScreen(),
      ),
    );
  }
}
