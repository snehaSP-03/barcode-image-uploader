import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../auth/errors.dart';
import '../models/product.dart';
import 'client.dart';

class InventoryApi {
  const InventoryApi._();

  /// `GET /inventory/by-barcode/{barcode}` — catalog lookup only.
  static Future<Product?> getByBarcode(String barcode) async {
    final cleaned = barcode.trim();
    if (cleaned.isEmpty) {
      throw const AuthException('Enter a barcode.', code: 'barcode_required');
    }

    try {
      final data = await apiRequest(
        '/inventory/by-barcode/${Uri.encodeComponent(cleaned)}',
      );
      if (data is! Map) return null;
      final raw = data['item'];
      if (raw is! Map) return null;
      return Product.fromJson(Map<String, dynamic>.from(raw));
    } on AuthException catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  /// `POST /inventory/{id}/images/presign`
  static Future<Map<String, String>> presignProductImage({
    required String itemId,
    String contentType = 'image/jpeg',
  }) async {
    final response = await apiRequest(
      '/inventory/${Uri.encodeComponent(itemId)}/images/presign',
      method: 'POST',
      body: {'content_type': contentType},
    );

    if (response is Map) {
      return {
        'upload_url': (response['upload_url'] ?? response['uploadUrl'] ?? '').toString(),
        's3_key': (response['s3_key'] ?? response['s3Key'] ?? '').toString(),
      };
    }
    return {};
  }

  /// Direct S3 PUT — no Cognito header. Content-Type must match presign.
  static Future<void> uploadImageBytesToS3({
    required String uploadUrl,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final res = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AuthException(
          'Failed to upload image to storage (HTTP ${res.statusCode}).',
          code: 'S3UploadError',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
        'Image upload failed. Please check network connection.',
        code: 'NetworkError',
      );
    }
  }

  /// `PATCH /inventory/{id}` with the full image_keys list (append-safe).
  static Future<Product> patchImageKeys({
    required String itemId,
    required List<String> imageKeys,
  }) async {
    final data = await apiRequest(
      '/inventory/${Uri.encodeComponent(itemId)}',
      method: 'PATCH',
      body: {'image_keys': imageKeys},
    );
    final raw = data is Map ? data['item'] : null;
    if (raw is! Map) {
      throw const AuthException('Could not save image keys.', code: 'patch_failed');
    }
    return Product.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Presign → S3 PUT → PATCH full keys. Prefer returned item (no extra GET).
  static Future<Product> appendProductImage({
    required Product product,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (product.imageKeys.length >= Product.maxImages) {
      throw const AuthException(
        'This product already has 5 photos. Remove one before adding more.',
        code: 'max_images',
      );
    }

    final presign = await presignProductImage(
      itemId: product.id,
      contentType: contentType,
    );
    final uploadUrl = presign['upload_url'] ?? '';
    final s3Key = presign['s3_key'] ?? '';
    if (uploadUrl.isEmpty || s3Key.isEmpty) {
      throw const AuthException(
        'Image storage is not configured on the server.',
        code: 'artifacts_bucket_missing',
      );
    }

    // Do not PATCH until PUT succeeds (avoids orphan keys).
    await uploadImageBytesToS3(
      uploadUrl: uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );

    final nextKeys = [...product.imageKeys, s3Key].take(Product.maxImages).toList();
    return patchImageKeys(itemId: product.id, imageKeys: nextKeys);
  }

  /// `DELETE /inventory/{id}/images` with `{ s3_key }`.
  static Future<Product> removeProductImage({
    required String itemId,
    required String s3Key,
  }) async {
    final data = await apiRequest(
      '/inventory/${Uri.encodeComponent(itemId)}/images',
      method: 'DELETE',
      body: {'s3_key': s3Key},
    );
    final raw = data is Map ? data['item'] : null;
    if (raw is! Map) {
      throw const AuthException('Could not remove image.', code: 'delete_failed');
    }
    return Product.fromJson(Map<String, dynamic>.from(raw));
  }

  static String contentTypeForPath(String path, {String? mimeType}) {
    if (mimeType != null && mimeType.isNotEmpty) {
      final lower = mimeType.toLowerCase();
      if (lower.contains('png')) return 'image/png';
      if (lower.contains('webp')) return 'image/webp';
      if (lower.contains('jpeg') || lower.contains('jpg')) return 'image/jpeg';
    }
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
