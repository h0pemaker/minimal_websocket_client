import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chatroom.dart';

class ChatService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<List<Chatroom>> fetchUserChatrooms(String userId) async {
    final url = '$baseUrl/api/chatrooms/user/$userId/chatrooms';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> chatroomListJson = jsonDecode(response.body);
        return chatroomListJson.map((json) => Chatroom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch user chatrooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user chatrooms: $e');
      return [];
    }
  }

  Future<List<Chatroom>> fetchAllChatrooms() async {
    final url = '$baseUrl/api/chatrooms';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> chatroomListJson = jsonDecode(response.body);
        return chatroomListJson.map((json) => Chatroom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch all chatrooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching all chatrooms: $e');
      return [];
    }
  }

  Future<List<String>> fetchUserMemberships(String userId) async {
    final url = '$baseUrl/api/memberships/user/$userId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> memberships = jsonDecode(response.body);
        return memberships
            .map((json) => json['chatroomId'] as String)
            .toList();
      } else {
        throw Exception('Failed to fetch memberships: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching memberships: $e');
      return [];
    }
  }

  Future<Chatroom?> createChatroom() async {
    final url = '$baseUrl/api/chatrooms';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: '{}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return Chatroom.fromJson(json);
      } else {
        throw Exception('Failed to create chatroom: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating chatroom: $e');
      return null;
    }
  }

  Future<bool> addMemberToChatroom({
    required String userId,
    required String chatroomId,
  }) async {
    final url = '$baseUrl/api/chatrooms/add?userId=$userId&chatroomId=$chatroomId';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to add member: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding member: $e');
      return false;
    }
  }

  Future<bool> deleteChatroom(String chatroomId) async {
    final url = '$baseUrl/api/chatrooms/$chatroomId';
    try {
      final response = await http.delete(Uri.parse(url));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting chatroom: $e');
      return false;
    }
  }
} 