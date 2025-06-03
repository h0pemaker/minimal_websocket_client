import 'package:flutter/material.dart';
import '../models/chatroom.dart';
import '../services/chat_service.dart';

class ChatroomListScreen extends StatefulWidget {
  final String userId;
  final Function(Chatroom) onChatroomSelected;
  final ChatService chatService;

  const ChatroomListScreen({
    Key? key,
    required this.userId,
    required this.onChatroomSelected,
    required this.chatService,
  }) : super(key: key);

  @override
  State<ChatroomListScreen> createState() => _ChatroomListScreenState();
}

class _ChatroomListScreenState extends State<ChatroomListScreen> {
  List<Chatroom> _chatrooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChatrooms();
  }

  Future<void> _fetchChatrooms() async {
    try {
      final chatrooms = await widget.chatService.fetchChatrooms(widget.userId);
      setState(() {
        _chatrooms = chatrooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chatrooms: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatrooms'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatrooms.isEmpty
              ? const Center(child: Text('No chatrooms available'))
              : RefreshIndicator(
                  onRefresh: _fetchChatrooms,
                  child: ListView.builder(
                    itemCount: _chatrooms.length,
                    itemBuilder: (context, index) {
                      final chatroom = _chatrooms[index];
                      return ListTile(
                        title: Text('Chatroom: ${chatroom.id}'),
                        onTap: () => widget.onChatroomSelected(chatroom),
                      );
                    },
                  ),
                ),
    );
  }
} 