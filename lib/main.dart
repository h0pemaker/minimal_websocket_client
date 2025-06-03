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

void main() {
  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
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

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }

  void _handleLogin(String userId) {
    setState(() => _userId = userId);
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
      onChatroomSelected: _handleChatroomSelected,
    );
  }
}