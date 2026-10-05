import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/inventory_api.dart';
import '../auth/errors.dart';
import '../models/product.dart';
import '../theme.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Product _product;
  bool _busy = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _pickAndUpload({required bool useCamera}) async {
    setState(() {
      _error = null;
      _status = null;
    });

    if (!_product.canAddImage) {
      setState(() {
        _error = 'This product already has 5 photos. Remove one before adding more.';
      });
      return;
    }

    final picker = ImagePicker();
    final List<XFile> files;

    try {
      if (useCamera) {
        final shot = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        files = shot == null ? const [] : [shot];
      } else {
        final picked = await picker.pickMultiImage(imageQuality: 85);
        final slots = _product.remainingImageSlots;
        files = picked.take(slots).toList();
        if (picked.length > slots && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only $slots more photo(s) allowed (max ${Product.maxImages}).'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = 'Could not open camera/gallery: $e');
      return;
    }

    if (files.isEmpty) return;

    setState(() => _busy = true);

    try {
      var current = _product;
      var uploaded = 0;

      for (final file in files) {
        if (current.imageKeys.length >= Product.maxImages) break;

        setState(() => _status = 'Uploading ${uploaded + 1} of ${files.length}…');

        final bytes = await file.readAsBytes();
        final contentType = InventoryApi.contentTypeForPath(
          file.name.isNotEmpty ? file.name : file.path,
          mimeType: file.mimeType,
        );

        // After each S3 PUT, PATCH full keys; use returned item for next append.
        current = await InventoryApi.appendProductImage(
          product: current,
          bytes: bytes,
          contentType: contentType,
        );
        uploaded += 1;
        if (mounted) setState(() => _product = current);
      }

      setState(() {
        _product = current;
        _status = uploaded == 1
            ? '1 photo uploaded successfully.'
            : '$uploaded photos uploaded successfully.';
      });
    } catch (e) {
      setState(() {
        _error = e is AuthException ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAt(int index) async {
    if (index < 0 || index >= _product.imageKeys.length) return;

    final key = _product.imageKeys[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text('This deletes the photo from the product.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });

    try {
      final updated = await InventoryApi.removeProductImage(
        itemId: _product.id,
        s3Key: key,
      );
      setState(() {
        _product = updated;
        _status = 'Photo removed.';
      });
    } catch (e) {
      setState(() {
        _error = e is AuthException ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _product.imageUrls;
    final atLimit = !_product.canAddImage;

    return Scaffold(
      appBar: AppBar(title: const Text('Product photos')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _metaRow('Barcode', _product.barcode),
                      if (_product.brand.isNotEmpty) _metaRow('Brand', _product.brand),
                      if (_product.sku.isNotEmpty) _metaRow('SKU', _product.sku),
                      _metaRow('Status', _product.status),
                      const SizedBox(height: 6),
                      Text(
                        'Photos ${_product.imageKeys.length}/${Product.maxImages}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || atLimit ? null : () => _pickAndUpload(useCamera: false),
                      child: Text(_busy ? 'Working…' : 'Pick from gallery'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || atLimit ? null : () => _pickAndUpload(useCamera: true),
                      child: const Text('Take photo'),
                    ),
                  ),
                ],
              ),
            ),
            if (atLimit)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Maximum 5 photos reached. Remove one to add another.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            if (_busy || _status != null || _error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy)
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _status ?? 'Working…',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    if (_status != null && !_busy)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_status!, style: const TextStyle(color: AppColors.success)),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
            Expanded(
              child: images.isEmpty
                  ? const Center(
                      child: Text(
                        'No photos yet. Add up to 5.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final hasKey = index < _product.imageKeys.length;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.surface,
                                ),
                                child: Image.network(
                                  images[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stackTrace) => const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (hasKey)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    iconSize: 18,
                                    color: Colors.white,
                                    tooltip: 'Remove photo',
                                    onPressed: _busy ? null : () => _removeAt(index),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value, style: const TextStyle(color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
