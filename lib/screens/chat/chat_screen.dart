import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Pushed as a normal route (unlike most of this app's tabs, which swap
/// content inline) since it's a focused, full-screen task with its own
/// header and message composer.
class ChatScreen extends StatelessWidget {
  final StreamChatClient client;
  final Channel channel;

  const ChatScreen({super.key, required this.client, required this.channel});

  @override
  Widget build(BuildContext context) {
    return StreamChat(
      client: client,
      child: StreamChannel(
        channel: channel,
        child: const StreamChannelPage(),
      ),
    );
  }
}
