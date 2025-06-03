import 'package:flutter/material.dart';
import '../models/chatroom.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

class ChatroomListScreen extends StatefulWidget {
  final String userId;
  final Function(Chatroom) onChatroomSelected;
  final ChatService chatService;
  final WebSocketService webSocketService;
  final bool isConnecting;
  final VoidCallback onLogout;

  const ChatroomListScreen({
    Key? key,
    required this.userId,
    required this.onChatroomSelected,
    required this.chatService,
    required this.webSocketService,
    required this.isConnecting,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<ChatroomListScreen> createState() => _ChatroomListScreenState();
}

class _ChatroomListScreenState extends State<ChatroomListScreen> {
  List<Chatroom> _chatrooms = [];
  bool _isLoading = true;
  bool _isCreatingChatroom = false;
  bool _isAddingMember = false;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _chatroomIdController = TextEditingController();
  Map<String, Message> _lastMessages = {};

  @override
  void initState() {
    super.initState();
    _fetchChatrooms();
    _setupMessageListener();
  }

  void _setupMessageListener() {
    widget.webSocketService.onMessageReceived = _handleMessageReceived;
  }

  void _handleMessageReceived(Message message) {
    setState(() {
      _lastMessages[message.chatroomId] = message;
      // Optionally refresh chatrooms list if needed
      _fetchChatrooms();
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _chatroomIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatrooms() async {
    try {
      final chatrooms = await widget.chatService.fetchChatrooms(widget.userId);
      if (mounted) {
        setState(() {
          _chatrooms = chatrooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chatrooms: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleCreateChatroom() async {
    setState(() => _isCreatingChatroom = true);

    try {
      final newChatroom = await widget.chatService.createChatroom();
      if (newChatroom != null) {
        await _fetchChatrooms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created chatroom: ${newChatroom.id}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating chatroom: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingChatroom = false);
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    _userIdController.clear();
    _chatroomIdController.clear();

    final theme = Theme.of(context);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Member to Chatroom',
          style: theme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'Enter user ID to add',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _chatroomIdController,
              decoration: const InputDecoration(
                labelText: 'Chatroom ID',
                hintText: 'Enter chatroom ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isAddingMember ? null : () => _handleAddMember(context),
            child: _isAddingMember
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add Member'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddMember(BuildContext context) async {
    final userId = _userIdController.text.trim();
    final chatroomId = _chatroomIdController.text.trim();

    if (userId.isEmpty || chatroomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both User ID and Chatroom ID'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isAddingMember = true);

    try {
      final success = await widget.chatService.addMemberToChatroom(
        userId: userId,
        chatroomId: chatroomId,
      );

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        await _fetchChatrooms();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add member'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding member: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingMember = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      widget.onLogout();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chatrooms'),
            Text(
              widget.isConnecting ? 'Connecting...' : 'Connected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.isConnecting ? AppColors.warning : AppColors.success,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatrooms.isEmpty
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
                        'No chatrooms yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a new chatroom to get started!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _chatrooms.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final chatroom = _chatrooms[index];
                    final lastMessage = _lastMessages[chatroom.id];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: ListTile(
                        leading: Hero(
                          tag: 'avatar-${chatroom.id}',
                          child: CircleAvatar(
                            backgroundColor: _getAvatarColor(chatroom.id),
                            child: Text(
                              chatroom.id.substring(0, 2).toUpperCase(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'Chatroom ${chatroom.id}',
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: lastMessage != null
                            ? Text(
                                '${lastMessage.senderId}: ${lastMessage.content}',
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                'No messages yet',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                        onTap: () => widget.onChatroomSelected(chatroom),
                      ),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'create-chatroom-fab',
            onPressed: _isCreatingChatroom ? null : _handleCreateChatroom,
            child: _isCreatingChatroom
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add-member-fab',
            onPressed: _showAddMemberDialog,
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }
} 