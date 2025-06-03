import 'package:flutter/material.dart';
import '../models/chatroom.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Chatroom chatroom;
  final String userId;
  final WebSocketService webSocketService;
  final VoidCallback onBack;

  const ChatScreen({
    Key? key,
    required this.chatroom,
    required this.userId,
    required this.webSocketService,
    required this.onBack,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    widget.webSocketService.initialize(
      userId: widget.userId,
      onMessageReceived: _handleMessageReceived,
      onConnected: () {
        print('Connected to WebSocket in chat screen');
      },
    );
  }

  void _handleMessageReceived(Message message) {
    if (message.chatroomId != widget.chatroom.id) return;

    setState(() {
      final index = _messages.indexWhere((msg) =>
          msg.timestamp?.millisecondsSinceEpoch == message.timestamp?.millisecondsSinceEpoch &&
          msg.senderId == message.senderId);

      if (index != -1) {
        _messages[index] = message;
      } else {
        _messages.add(message);
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    widget.webSocketService.sendMessage(widget.chatroom.id, text);
    _messageController.clear();
  }

  void _handleReadUpdate(Message message) {
    widget.webSocketService.sendReadUpdate(message);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Chatroom: ${widget.chatroom.id}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  message: message,
                  isMine: message.senderId == widget.userId,
                  onReadUpdate: _handleReadUpdate,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
