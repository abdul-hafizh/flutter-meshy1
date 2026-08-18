/// Display-only — the backend always recomputes the actual charge from
/// [quantity] server-side (see `POST /ai-credits/purchase`), this is just
/// what the packages look like in the UI.
class TokenPackage {
  final int quantity;
  final int price;

  const TokenPackage({required this.quantity, required this.price});

  static const int rupiahPerToken = 1000;

  static const List<TokenPackage> all = [
    TokenPackage(quantity: 40, price: 40 * rupiahPerToken),
    TokenPackage(quantity: 50, price: 50 * rupiahPerToken),
    TokenPackage(quantity: 100, price: 100 * rupiahPerToken),
  ];
}
