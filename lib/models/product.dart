class Product {
  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.imageUrls,
    required this.imageKeys,
    this.sku = '',
    this.brand = '',
    this.category = '',
    this.status = 'ACTIVE',
  });

  static const maxImages = 5;

  final String id;
  final String name;
  final String barcode;
  final String sku;
  final String brand;
  final List<String> imageUrls;
  final List<String> imageKeys;
  final String category;
  final String status;

  bool get canAddImage => imageKeys.length < maxImages;
  int get remainingImageSlots => (maxImages - imageKeys.length).clamp(0, maxImages);

  factory Product.fromJson(Map<String, dynamic> raw) {
    final urls = <String>[];
    final rawUrls = raw['image_urls'] ?? raw['imageUrls'];
    if (rawUrls is List) {
      for (final u in rawUrls) {
        final s = u?.toString().trim() ?? '';
        if (s.isNotEmpty) urls.add(s);
      }
    }

    // Keep image_keys only from the API — never invent keys from image_urls.
    final keys = <String>[];
    final rawKeys = raw['image_keys'] ?? raw['imageKeys'];
    if (rawKeys is List) {
      for (final k in rawKeys) {
        final s = k?.toString().trim() ?? '';
        if (s.isNotEmpty) keys.add(s);
      }
    }

    return Product(
      id: (raw['item_id'] ?? raw['id'] ?? '').toString(),
      name: (raw['name'] ?? '').toString(),
      barcode: (raw['barcode'] ?? '').toString(),
      sku: (raw['sku'] ?? '').toString(),
      brand: (raw['brand'] ?? '').toString(),
      imageUrls: urls,
      imageKeys: keys,
      category: (raw['category_id'] ?? raw['category'] ?? '').toString(),
      status: (raw['status'] ?? 'ACTIVE').toString(),
    );
  }
}
