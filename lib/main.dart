import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'models/chatroom.dart';
import 'screens/login_screen.dart';
import 'screens/chatroom_list_screen.dart';
import 'screens/chat_screen.dart';
import 'services/chat_service.dart';
import 'services/websocket_service.dart';
import 'services/auth_service.dart';
import 'config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: AppTheme.lightTheme,
      home: const ChatApp(),
    );
  }
}

class ChatApp extends StatefulWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  String? _userId;
  final _chatService = ChatService();
  final _webSocketService = WebSocketService();
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _loadSavedUserId();
  }

  void _loadSavedUserId() {
    final savedUserId = AuthService.getUserId();
    if (savedUserId != null) {
      setState(() => _userId = savedUserId);
      _initializeWebSocket(savedUserId);
    }
  }

  void _initializeWebSocket(String userId) {
    _webSocketService.initialize(
      userId: userId,
      onConnectionStateChanged: (isConnected) {
        if (mounted) {
          setState(() => _isConnecting = !isConnected);
        }
      },
    );
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }

  void _handleLogin(String userId) {
    setState(() => _userId = userId);
    _initializeWebSocket(userId);
  }

  void _handleLogout() {
    _webSocketService.dispose();
    setState(() {
      _userId = null;
      _isConnecting = true;
    });
  }

  void _handleChatroomSelected(Chatroom chatroom) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatroom: chatroom,
          userId: _userId!,
          webSocketService: _webSocketService,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return LoginScreen(onLogin: _handleLogin);
    }

    return ChatroomListScreen(
      userId: _userId!,
      chatService: _chatService,
      webSocketService: _webSocketService,
      isConnecting: _isConnecting,
      onChatroomSelected: _handleChatroomSelected,
      onLogout: _handleLogout,
    );
  }
}