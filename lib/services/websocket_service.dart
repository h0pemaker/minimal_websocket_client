import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);
typedef ConnectionCallback = void Function();

class WebSocketService {
  static const String baseUrl = 'ws://10.0.2.2:3000';
  
  StompClient? _stompClient;
  String? _userId;
  MessageCallback? _onMessageReceived;
  ConnectionCallback? _onConnected;

  set onMessageReceived(MessageCallback callback) {
    _onMessageReceived = callback;
  }

  set onConnected(ConnectionCallback callback) {
    _onConnected = callback;
  }

  void initialize({
    required String userId,
    MessageCallback? onMessageReceived,
    ConnectionCallback? onConnected,
  }) {
    _userId = userId;
    if (onMessageReceived != null) _onMessageReceived = onMessageReceived;
    if (onConnected != null) _onConnected = onConnected;
    _connect();
  }

  void _connect() {
    if (_userId == null) return;

    final websocketUrl = '$baseUrl/ws?userId=$_userId';

    _stompClient = StompClient(
      config: StompConfig(
        url: websocketUrl,
        onConnect: _onConnect,
        onStompError: (frame) => print('STOMP Error: ${frame.body}'),
        onWebSocketError: (error) => print('WebSocket Error: $error'),
        onDisconnect: (frame) => print('Disconnected'),
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    _stompClient!.activate();
  }

  void _onConnect(StompFrame frame) {
    print('Connected to STOMP WebSocket');
    _onConnected?.call();

    _stompClient?.subscribe(
      destination: '/user/queue/messages',
      callback: (frame) {
        final msgBody = frame.body ?? '';
        final messageId = _extractMessageId(msgBody);
        _sendAck(messageId);

        try {
          final decodedJson = jsonDecode(msgBody);
          final message = Message.fromJson(decodedJson);
          _onMessageReceived?.call(message);
        } catch (e) {
          print('Error decoding message JSON: $e');
        }
      },
    );
  }

  String _extractMessageId(String? body) {
    if (body == null || body.isEmpty) return '';
    try {
      final jsonData = jsonDecode(body);
      return jsonData['id'] ?? jsonData['messageId'] ?? '';
    } catch (e) {
      print('Error parsing message body: $e');
      return '';
    }
  }

  void _sendAck(String messageId) {
    if (messageId.isEmpty) return;
    final ackPayload = jsonEncode({'messageId': messageId});
    _stompClient?.send(destination: '/app/acknowledge', body: ackPayload);
    print('Sent ack for messageId: $messageId');
  }

  void sendMessage(String chatroomId, String content) {
    if (_userId == null || _stompClient == null) return;

    final now = DateTime.now();
    final messagePayload = jsonEncode({
      'senderId': _userId,
      'chatroomId': chatroomId,
      'content': content,
      'timestamp': now.toIso8601String(),
    });

    _stompClient?.send(
      destination: '/app/chat.sendMessage/$chatroomId',
      body: messagePayload,
    );
  }

  void sendReadUpdate(Message message) {
    String? messageId = message.id;
    String chatroomId = message.chatroomId;
    if (messageId == null || messageId.isEmpty || _stompClient == null) return;

    print("read update sent");
    print("userId : $_userId "+"messageId : $messageId "+"chatroomId : $chatroomId");

    final payload = jsonEncode({
      'messageId': messageId,
      'chatroomId': chatroomId,
    });

    _stompClient?.send(destination: '/app/chat.readUpdate', body: payload);
  }

  void dispose() {
    _stompClient?.deactivate();
    _stompClient = null;
    _userId = null;
    _onMessageReceived = null;
    _onConnected = null;
  }
} 