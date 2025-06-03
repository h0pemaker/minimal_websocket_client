import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chatroom.dart';

class ChatService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<List<Chatroom>> fetchChatrooms(String userId) async {
    final url = '$baseUrl/api/chatrooms/user/$userId/chatrooms';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> chatroomListJson = jsonDecode(response.body);
        return chatroomListJson.map((json) => Chatroom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch chatrooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching chatrooms: $e');
      return [];
    }
  }
} 