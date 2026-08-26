import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../services/chat_service.dart';

/// Lazily connects to GetStream Chat the first time the user opens a chat,
/// rather than at login — chat is one of several tabs and most sessions
/// never open it, so holding a persistent websocket for the whole app
/// lifetime isn't worth it.
class ChatController extends ChangeNotifier {
  StreamChatClient? _client;

  StreamChatClient? get client => _client;
  bool get isConnected => _client?.state.currentUser != null;

  Future<StreamChatClient> ensureConnected(String appToken) async {
    final existing = _client;
    if (existing != null && isConnected) return existing;

    final result = await ChatService.fetchToken(token: appToken);
    final client = StreamChatClient(result.apiKey);
    await client.connectUser(
      User(id: result.userId, name: result.fullName ?? result.userId, image: result.avatar),
      result.token,
    );
    _client = client;
    notifyListeners();
    return client;
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    if (client != null) {
      await client.disconnectUser();
    }
    notifyListeners();
  }
}
