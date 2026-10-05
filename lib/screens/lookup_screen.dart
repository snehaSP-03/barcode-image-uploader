import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/inventory_api.dart';
import '../auth/auth_store.dart';
import '../auth/errors.dart';
import '../theme.dart';
import 'barcode_scanner_screen.dart';
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

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again with your Ops/Admin account to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthStore.instance.logout();
    }
  }

  Future<void> _openScanner() async {
    setState(() {
      _error = null;
      _notInCatalogBarcode = null;
    });

    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (!mounted || scanned == null || scanned.isEmpty) return;

    // Keep digits for product barcodes; if scan has letters (CODE128), keep as-is.
    final value = scanned.trim();
    _barcodeController.text = value;
    await _lookup();
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
        _error = 'Scan or enter a barcode.';
      });
      return;
    }

    try {
      final product = await InventoryApi.getByBarcode(barcode);
      if (!mounted) return;
      if (product == null) {
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
            onPressed: _confirmLogout,
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
                      'Scan with the camera, or type the barcode, then look up the product.',
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loading ? null : _openScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan barcode'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'or enter manually',
                            style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 13),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Barcode',
                        hintText: 'e.g. 8902080001361',
                        suffixIcon: IconButton(
                          tooltip: 'Scan',
                          onPressed: _loading ? null : _openScanner,
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
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
                    OutlinedButton(
                      onPressed: _loading ? null : _lookup,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
