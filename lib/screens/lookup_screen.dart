import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/inventory_api.dart';
import '../auth/auth_store.dart';
import '../auth/errors.dart';
import '../theme.dart';
import 'product_screen.dart';

class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key});

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  final _barcodeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _notInCatalogBarcode;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final barcode = _barcodeController.text.trim();
    setState(() {
      _error = null;
      _notInCatalogBarcode = null;
      _loading = true;
    });

    if (barcode.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Enter a barcode.';
      });
      return;
    }

    try {
      final product = await InventoryApi.getByBarcode(barcode);
      if (!mounted) return;
      if (product == null) {
        // 404 not_found — stop. Do not create / enrich.
        setState(() => _notInCatalogBarcode = barcode);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductScreen(product: product)),
      );
    } catch (e) {
      setState(() {
        _error = e is AuthException ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Photos'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => AuthStore.instance.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Signed in as ${auth.displayName}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Scan or enter barcode',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Looks up an existing catalog product, then lets you add photos (max 5).',
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        hintText: 'e.g. 8902080001361',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.search,
                      enabled: !_loading,
                      onSubmitted: (_) => _lookup(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ],
                    if (_notInCatalogBarcode != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Product not in catalog\nBarcode $_notInCatalogBarcode is not onboarded. '
                          'This app does not create SKUs.',
                          style: const TextStyle(color: AppColors.danger, height: 1.4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _lookup,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Find product'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
