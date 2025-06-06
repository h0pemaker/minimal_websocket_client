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
  Set<String> _userChatroomIds = {};
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
      final results = await Future.wait<List<dynamic>>([
        widget.chatService.fetchAllChatrooms(),
        widget.chatService.fetchUserMemberships(widget.userId),
      ]);

      final List<Chatroom> chatrooms = results[0] as List<Chatroom>;
      final List<String> userChatroomIds = results[1] as List<String>;

      if (mounted) {
        setState(() {
          _chatrooms = chatrooms;
          _userChatroomIds = userChatroomIds.toSet();
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

  Future<void> _handleJoinChatroom(String chatroomId) async {
    try {
      final success = await widget.chatService.addMemberToChatroom(
        userId: widget.userId,
        chatroomId: chatroomId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined chatroom'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchChatrooms();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining chatroom: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteChatroom(String chatroomId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chatroom'),
        content: const Text('Are you sure you want to delete this chatroom? This action cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final success = await widget.chatService.deleteChatroom(chatroomId);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chatroom deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _fetchChatrooms();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting chatroom: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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

  void _showChatroomActions(BuildContext context, Chatroom chatroom, bool isMember) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryText.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'avatar-${chatroom.id}-modal',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _getAvatarColor(chatroom.id),
                            shape: BoxShape.circle,
                            border: isMember
                                ? Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              chatroom.id.substring(0, 2).toUpperCase(),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isMember
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.secondaryText.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isMember ? 'Member' : 'Not a member',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isMember
                                      ? AppColors.primary
                                      : AppColors.secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.secondaryText.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 8),
                if (isMember)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chat_outlined,
                        color: AppColors.accent,
                      ),
                    ),
                    title: Text(
                      'Open Chat',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.accent,
                      ),
                    ),
                    subtitle: Text(
                      'View messages and chat with members',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onChatroomSelected(chatroom);
                    },
                  )
                else
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_add_outlined,
                        color: AppColors.info,
                      ),
                    ),
                    title: Text(
                      'Join Chatroom',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.info,
                      ),
                    ),
                    subtitle: Text(
                      'Become a member to start chatting',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _handleJoinChatroom(chatroom.id);
                    },
                  ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                  ),
                  title: Text(
                    'Delete Chatroom',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'This action cannot be undone',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleDeleteChatroom(chatroom.id);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
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
                        'No chatrooms available',
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
                    final isMember = _userChatroomIds.contains(chatroom.id);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: InkWell(
                        onTap: isMember ? () => widget.onChatroomSelected(chatroom) : null,
                        onLongPress: () => _showChatroomActions(context, chatroom, isMember),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'avatar-${chatroom.id}',
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _getAvatarColor(chatroom.id),
                                    shape: BoxShape.circle,
                                    border: isMember
                                        ? Border.all(
                                            color: AppColors.success,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      chatroom.id.substring(0, 2).toUpperCase(),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chatroom ${chatroom.id}',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    if (lastMessage != null)
                                      Text(
                                        '${lastMessage.senderId}: ${lastMessage.content}',
                                        style: theme.textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else
                                      Text(
                                        isMember ? 'No messages yet' : 'Tap and hold for options',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.secondaryText,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
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
    );
  }
} 