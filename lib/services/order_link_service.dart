import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../models/physical_order.dart';

/// Sends an `ORDER_LINK` card (rendered by OrderLinkAttachmentBuilder in the
/// app and CustomAttachment in the merchant dashboard) into a chat.
class OrderLinkService {
  OrderLinkService._();

  /// Whether this chat already holds a link to [orderId] — among the
  /// messages the channel has loaded, which is the latest page.
  static bool alreadyShared(Channel channel, String orderId) =>
      (channel.state?.messages ?? const <Message>[]).any(
        (m) => m.attachments.any((a) => a.type == 'ORDER_LINK' && a.extraData['orderId']?.toString() == orderId),
      );

  /// [customerUserId] is the ordering customer (picks the right title and
  /// picture, see PhysicalOrder.display). With [skipIfAlreadyShared] the
  /// card isn't posted again when the chat already has one for this order —
  /// for automatic sends, so reopening a chat doesn't spam the merchant.
  /// Returns whether a message was sent.
  static Future<bool> send(
    Channel channel,
    PhysicalOrder order, {
    String? customerUserId,
    bool skipIfAlreadyShared = false,
  }) async {
    if (channel.state == null) await channel.watch();
    if (skipIfAlreadyShared && alreadyShared(channel, order.id)) return false;

    // Title + picture are snapshotted into the message itself (like
    // PRODUCT_LINK's thumbnailPath), so both apps can render the card
    // without fetching the order.
    final display = order.display(customerUserId: customerUserId);
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
              'title': display.title,
              'thumbnailPath': display.imageUrl,
            },
          ),
        ],
      ),
    );
    return true;
  }
}
