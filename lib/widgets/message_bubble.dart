import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Function(Message) onReadUpdate;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMine,
    required this.onReadUpdate,
  }) : super(key: key);

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return Icons.hourglass_bottom;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return Colors.grey;
      case MessageStatus.sent:
        return Colors.black;
      case MessageStatus.delivered:
        return Colors.black;
      case MessageStatus.read:
        return Colors.blue;
      case MessageStatus.failed:
        return Colors.red;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key("visibility_detector-${message.id}"),
      onVisibilityChanged: (VisibilityInfo info) {
        if (info.visibleFraction > 0.7 && message.status != MessageStatus.read && !isMine) {
          onReadUpdate(message);
        }
      },
      child: Align(
        alignment: !isMine ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isMine ? Colors.blue[100] : Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          child: Column(
            crossAxisAlignment: !isMine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              if (message.contentIsImageUrl)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Image.network(
                    message.content,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              message.contentIsImageUrl
                  ? GestureDetector(
                      onTap: () => _launchUrl(message.content),
                      child: Text(
                        message.content,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  : Text(message.content),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.timestamp?.toLocal().toString().split('.')[0] ?? '',
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                  if (isMine && message.status != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _getStatusIcon(message.status!),
                      size: 14,
                      color: _getStatusColor(message.status!),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 