import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../providers/chat_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/chat_service.dart';
import 'chat_screen.dart';

/// Opens (creating if needed) the customer's chat with a store and shows it.
/// Errors are shown as a snackbar; returns once the chat screen is closed.
Future<void> openStoreChat(BuildContext context, String merchantId) async {
  final token = context.read<AuthController>().token;
  if (token == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final client = await context.read<ChatController>().ensureConnected(token);
    final info = await ChatService.createOrGetChannel(token: token, merchantId: merchantId);
    final channel = client.channel(info.channelType, id: info.channelId);
    await navigator.push(MaterialPageRoute(builder: (_) => ChatScreen(client: client, channel: channel)));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Gagal membuka chat.')));
  }
}
