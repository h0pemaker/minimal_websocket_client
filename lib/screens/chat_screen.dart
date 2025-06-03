import 'package:flutter/material.dart';
import '../models/chatroom.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../widgets/message_bubble.dart';
import '../config/theme.dart';

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
    widget.webSocketService.onMessageReceived = _handleMessageReceived;
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Row(
          children: [
            Hero(
              tag: 'avatar-${widget.chatroom.id}',
              child: CircleAvatar(
                backgroundColor: _getAvatarColor(widget.chatroom.id),
                child: Text(
                  _getInitials(widget.chatroom.id),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chatroom ${widget.chatroom.id}',
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String chatroomId) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
      AppColors.success,
    ];
    final colorIndex = chatroomId.hashCode % colors.length;
    return colors[colorIndex];
  }

  String _getInitials(String chatroomId) {
    return chatroomId.length > 2 ? chatroomId.substring(0, 2).toUpperCase() : chatroomId.toUpperCase();
  }
}
