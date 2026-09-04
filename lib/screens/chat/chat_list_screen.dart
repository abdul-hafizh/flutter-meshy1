import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../../models/merchant.dart';
import '../../providers/auth_controller.dart';
import '../../providers/chat_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';

/// Customer's chat inbox, reachable from the chat icon on the home screen
/// header. Lists every conversation the customer already has with a
/// merchant, and lets them start a new one via [_NewChatSheet].
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  StreamChatClient? _client;
  StreamChannelListController? _listController;
  bool _loading = true;
  String? _error;
  bool _openingNewChat = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _listController?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = context.read<AuthController>().token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Sesi kamu berakhir. Silakan login ulang.';
      });
      return;
    }
    try {
      final client = await context.read<ChatController>().ensureConnected(token);
      final userId = client.state.currentUser!.id;
      final controller = StreamChannelListController(
        client: client,
        filter: Filter.in_('members', [userId]),
        channelStateSort: const [SortOption.desc('last_message_at')],
      );
      if (!mounted) return;
      setState(() {
        _client = client;
        _listController = controller;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal membuka chat. Coba lagi.';
      });
    }
  }

  Future<void> _startNewChat() async {
    final client = _client;
    final token = context.read<AuthController>().token;
    if (client == null || token == null) return;

    final merchant = await showModalBottomSheet<Merchant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewChatSheet(),
    );
    if (merchant == null || !mounted) return;

    setState(() => _openingNewChat = true);
    try {
      final info = await ChatService.createOrGetChannel(token: token, merchantId: merchant.id);
      final channel = client.channel(info.channelType, id: info.channelId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(client: client, channel: channel)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka chat. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _openingNewChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButton: _client == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openingNewChat ? null : _startNewChat,
              icon: _openingNewChat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_comment_rounded),
              label: const Text('Chat Baru'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: () {
                  setState(() => _loading = true);
                  _connect();
                })
              : StreamChat(
                  client: _client!,
                  child: StreamChannelListView(
                    controller: _listController!,
                    emptyBuilder: (context) => const _EmptyChatState(),
                    onChannelTap: (channel) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(client: _client!, channel: channel),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textFaint),
            const SizedBox(height: 12),
            const Text(
              'Belum ada percakapan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mulai chat dengan penjual lewat tombol di bawah.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing merchants a customer can start a fresh conversation
/// with — reused from the same `/chat/merchants` list `JobDetailView` uses,
/// but without any order attached (`jobId` stays null).
class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  bool _loading = true;
  List<Merchant> _merchants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final merchants = await ChatService.listMerchants(token: token);
      if (!mounted) return;
      setState(() => _merchants = merchants);
    } catch (_) {
      // Best-effort — the sheet just shows an empty state below.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Pilih Penjual',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _merchants.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Belum ada penjual yang tersedia.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: _merchants.length,
                          separatorBuilder: (context, i) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final merchant = _merchants[i];
                            return _MerchantOption(
                              merchant: merchant,
                              onTap: () => Navigator.of(context).pop(merchant),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantOption extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onTap;

  const _MerchantOption({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surface,
                backgroundImage:
                    merchant.avatar != null && merchant.avatar!.isNotEmpty
                        ? NetworkImage(merchant.avatar!)
                        : null,
                child: merchant.avatar == null || merchant.avatar!.isEmpty
                    ? const Icon(Icons.storefront_rounded, size: 18, color: AppColors.purple)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      merchant.fullName.isNotEmpty ? merchant.fullName : 'Penjual',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (merchant.address != null && merchant.address!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          merchant.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
