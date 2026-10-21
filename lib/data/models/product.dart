class Product {
  const Product({
    required this.id,
    required this.game,
    required this.setName,
    required this.skuType,
    required this.displayName,
    required this.isCanonical,
    this.releaseDate,
  });

  final String id;
  final String game;
  final String setName;
  final String skuType;
  final String displayName;
  final bool isCanonical;
  final DateTime? releaseDate;

  factory Product.fromRow(Map<String, dynamic> r) => Product(
        id: r['id'] as String,
        game: r['game'] as String,
        setName: r['set_name'] as String,
        skuType: r['sku_type'] as String,
        displayName: r['display_name'] as String,
        isCanonical: r['is_canonical'] as bool? ?? true,
        releaseDate: r['release_date'] == null ? null : DateTime.parse(r['release_date'] as String),
      );
}
