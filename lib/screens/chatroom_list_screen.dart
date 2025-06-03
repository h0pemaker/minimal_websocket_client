import 'package:flutter/material.dart';
import '../models/chatroom.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../config/theme.dart';

class ChatroomListScreen extends StatefulWidget {
  final String userId;
  final Function(Chatroom) onChatroomSelected;
  final ChatService chatService;
  final VoidCallback onLogout;

  const ChatroomListScreen({
    Key? key,
    required this.userId,
    required this.onChatroomSelected,
    required this.chatService,
    required this.onLogout,
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
              'User ID: ${widget.userId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _chatrooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: AppColors.secondaryText.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No chatrooms available',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull to refresh the list',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchChatrooms,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _chatrooms.length,
                    itemBuilder: (context, index) {
                      final chatroom = _chatrooms[index];
                      final avatarColor = _getAvatarColor(chatroom.id);
                      final initials = _getInitials(chatroom.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: InkWell(
                          onTap: () => widget.onChatroomSelected(chatroom),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'avatar-${chatroom.id}',
                                  child: CircleAvatar(
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      initials,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chatroom ${chatroom.id}',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to join the conversation',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppColors.secondaryText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
} 