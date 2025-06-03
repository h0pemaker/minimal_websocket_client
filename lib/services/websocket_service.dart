import 'dart:convert';
import 'dart:async';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);
typedef ConnectionStateCallback = void Function(bool isConnected);

class WebSocketService {
  static const String baseUrl = 'ws://10.0.2.2:3000';
  
  StompClient? _stompClient;
  String? _userId;
  MessageCallback? _onMessageReceived;
  ConnectionStateCallback? _onConnectionStateChanged;
  Timer? _reconnectionTimer;
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  static const _reconnectInterval = Duration(seconds: 3);
  static const _heartbeatInterval = Duration(seconds: 5);

  bool get isConnected => _isConnected;

  set onMessageReceived(MessageCallback callback) {
    _onMessageReceived = callback;
  }

  set onConnectionStateChanged(ConnectionStateCallback callback) {
    _onConnectionStateChanged = callback;
  }

  void initialize({
    required String userId,
    MessageCallback? onMessageReceived,
    ConnectionStateCallback? onConnectionStateChanged,
  }) {
    _userId = userId;
    if (onMessageReceived != null) _onMessageReceived = onMessageReceived;
    if (onConnectionStateChanged != null) _onConnectionStateChanged = onConnectionStateChanged;
    _connect();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _verifyConnection();
    });
  }

  void _verifyConnection() {
    if (_stompClient == null || !_stompClient!.connected) {
      _handleDisconnection();
      return;
    }

    // Send a ping message to verify connection
    // try {
    //   _stompClient?.send(
    //     destination: '/app/ping',
    //     body: '{}',
    //     headers: {},
    //   );
    // } catch (e) {
    //   print('Error sending ping: $e');
    //   _handleDisconnection();
    // }
  }

  void _updateConnectionState(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _onConnectionStateChanged?.call(connected);

      if (!connected) {
        // Clear any existing connection
        _stompClient?.deactivate();
        _stompClient = null;
      }
    }
  }

  void _connect() {
    if (_userId == null) return;

    // If already trying to connect, don't try again
    if (_stompClient != null) {
      _stompClient?.deactivate();
      _stompClient = null;
    }

    final websocketUrl = '$baseUrl/ws?userId=$_userId';

    _stompClient = StompClient(
      config: StompConfig(
        url: websocketUrl,
        onConnect: _onConnect,
        onStompError: (frame) {
          print('STOMP Error: ${frame.body}');
          _handleDisconnection();
        },
        onWebSocketError: (error) {
          print('WebSocket Error: $error');
          _handleDisconnection();
        },
        onDisconnect: (frame) {
          print('Disconnected');
          _handleDisconnection();
        },
        heartbeatOutgoing: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 5),
        reconnectDelay: const Duration(milliseconds: 0),
      ),
    );

    try {
      _stompClient!.activate();
    } catch (e) {
      print('Error activating WebSocket: $e');
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    _updateConnectionState(false);
    _scheduleReconnection();
  }

  void _scheduleReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(_reconnectInterval, () {
      if (!_isConnected && _userId != null) {
        print('Attempting to reconnect...');
        _connect();
      }
    });
  }

  void _onConnect(StompFrame frame) {
    print('Connected to STOMP WebSocket');
    _updateConnectionState(true);
    _reconnectionTimer?.cancel();

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

    // Subscribe to server heartbeat
    // _stompClient?.subscribe(
    //   destination: '/topic/heartbeat',
    //   callback: (_) {
    //     // Connection is alive
    //   },
    // );
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
    if (_userId == null || _stompClient == null || !_isConnected) return;

    final now = DateTime.now();
    final messagePayload = jsonEncode({
      'senderId': _userId,
      'chatroomId': chatroomId,
      'content': content,
      'timestamp': now.toIso8601String(),
    });

    try {
      _stompClient?.send(
        destination: '/app/chat.sendMessage/$chatroomId',
        body: messagePayload,
      );
    } catch (e) {
      print('Error sending message: $e');
      _handleDisconnection();
    }
  }

  void sendReadUpdate(Message message) {
    if (!_isConnected) return;
    
    String? messageId = message.id;
    String chatroomId = message.chatroomId;
    if (messageId == null || messageId.isEmpty || _stompClient == null) return;

    final payload = jsonEncode({
      'messageId': messageId,
      'chatroomId': chatroomId,
    });

    try {
      _stompClient?.send(destination: '/app/chat.readUpdate', body: payload);
    } catch (e) {
      print('Error sending read update: $e');
      _handleDisconnection();
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectionTimer?.cancel();
    _stompClient?.deactivate();
    _stompClient = null;
    _userId = null;
    _onMessageReceived = null;
    _onConnectionStateChanged = null;
    _isConnected = false;
  }
} 