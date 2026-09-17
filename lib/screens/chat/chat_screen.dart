import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../../models/physical_order.dart';
import '../../providers/auth_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat/link_attachment_builders.dart';

String _rupiah(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buf.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
  }
  return 'Rp $buf';
}

/// Pushed as a normal route (unlike most of this app's tabs, which swap
/// content inline) since it's a focused, full-screen task with its own
/// header and message composer.
///
/// This mirrors `StreamChannelPage` (the package's own all-in-one channel
/// screen) by hand instead of using it directly, since that page doesn't
/// expose a way to add a header action button — needed here for "Kirim
/// Pesanan" (share an order link into the chat). It also registers custom
/// attachment builders so `PRODUCT_LINK`/`ORDER_LINK` messages (sent from
/// here or from [ProductDetailScreen]) render as tappable cards instead of
/// falling back to the SDK's generic "unsupported attachment" placeholder.
class ChatScreen extends StatefulWidget {
  final StreamChatClient client;
  final Channel channel;

  const ChatScreen({super.key, required this.client, required this.channel});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final FocusNode _focusNode = FocusNode();
  late final StreamMessageComposerController _messageComposerController = StreamMessageComposerController();
  bool _sendingOrderLink = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _messageComposerController.dispose();
    super.dispose();
  }

  void _reply(Message message) {
    _messageComposerController.quotedMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  void _editMessage(Message message) {
    _messageComposerController.editMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  Future<void> _shareOrder() async {
    final order = await showModalBottomSheet<PhysicalOrder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OrderPickerSheet(),
    );
    if (order == null || !mounted) return;

    setState(() => _sendingOrderLink = true);
    try {
      final channel = widget.channel;
      if (channel.state == null) await channel.watch();
      await channel.sendMessage(
        Message(
          text: '🔗 Pesanan #${order.orderNumber ?? order.id}',
          attachments: [
            Attachment(
              type: 'ORDER_LINK',
              uploadState: const UploadState.success(),
              extraData: {
                'orderId': order.id,
                'orderNumber': order.orderNumber,
                'totalAmount': order.totalAmount,
              },
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim link pesanan.')),
      );
    } finally {
      if (mounted) setState(() => _sendingOrderLink = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = StreamChannelHeader(
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _sendingOrderLink ? null : _shareOrder,
            tooltip: 'Kirim Pesanan',
            icon: _sendingOrderLink
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
    );

    final composer = StreamMessageComposer(
      focusNode: _focusNode,
      messageComposerController: _messageComposerController,
      onQuotedMessageCleared: _messageComposerController.clearQuotedMessage,
      enableVoiceRecording: true,
    );

    final typingIndicator = StreamTypingIndicator(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      style: context.streamTextTheme.captionDefault.copyWith(
        color: context.streamColorScheme.textSecondary,
      ),
    );

    return StreamChat(
      client: widget.client,
      configData: StreamChatConfigurationData(
        attachmentBuilders: const [
          ProductLinkAttachmentBuilder(),
          OrderLinkAttachmentBuilder(),
        ],
      ),
      child: StreamChannel(
        channel: widget.channel,
        child: StreamScaffold(
          appBar: appBar,
          bottom: composer,
          appBarSurfaceStyle: StreamChannelHeader.resolveSurfaceStyle(context),
          bottomSurfaceStyle: StreamMessageComposer.resolveSurfaceStyle(context),
          body: Stack(
            children: [
              StreamMessageListView(
                onEditMessageTap: _editMessage,
                onReplyTap: _reply,
                threadBuilder: (_, parentMessage) => StreamThreadPage(parent: parentMessage!),
                enableSafeArea: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(top: false, child: typingIndicator),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the customer's own priced orders — the merchant-side
/// equivalent (picking one of THEIR OWN orders/products) lives in the
/// Next.js dashboard, since this Flutter app has no merchant role.
class _OrderPickerSheet extends StatefulWidget {
  const _OrderPickerSheet();

  @override
  State<_OrderPickerSheet> createState() => _OrderPickerSheetState();
}

class _OrderPickerSheetState extends State<_OrderPickerSheet> {
  bool _loading = true;
  List<PhysicalOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final orders = await OrderService.listMine(token: token);
      if (!mounted) return;
      setState(() => _orders = orders.where((o) => o.isPriced).toList());
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
                    'Pilih Pesanan',
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
                  : _orders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Belum ada pesanan yang bisa dikirim.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: _orders.length,
                          separatorBuilder: (context, i) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final order = _orders[i];
                            return _OrderOption(
                              order: order,
                              onTap: () => Navigator.of(context).pop(order),
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

class _OrderOption extends StatelessWidget {
  final PhysicalOrder order;
  final VoidCallback onTap;

  const _OrderOption({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final totalAmount = order.totalAmount;
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradientSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${order.orderNumber ?? order.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (totalAmount != null)
                      Text(
                        _rupiah(totalAmount),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
