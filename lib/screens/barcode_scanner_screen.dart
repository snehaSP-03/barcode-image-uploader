import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme.dart';

/// Full-screen camera scanner. Pops with the scanned barcode string.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf14,
    ],
  );

  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;

      // Prefer digit barcodes for product EAN/UPC; still accept other formats.
      final value = raw.replaceAll(RegExp(r'\s+'), '');
      if (value.isEmpty) continue;

      _handled = true;
      _controller.stop();
      if (mounted) {
        Navigator.of(context).pop<String>(value);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            tooltip: _torchOn ? 'Torch off' : 'Torch on',
            onPressed: () async {
              await _controller.toggleTorch();
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _ScanFramePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              'Point the camera at the product barcode',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final frameSize = Size(size.width * 0.78, size.width * 0.42);
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: frameSize.width,
      height: frameSize.height,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final border = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      border,
    );

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const len = 22.0;
    // Top-left
    canvas.drawLine(frameRect.topLeft, frameRect.topLeft + const Offset(len, 0), corner);
    canvas.drawLine(frameRect.topLeft, frameRect.topLeft + const Offset(0, len), corner);
    // Top-right
    canvas.drawLine(frameRect.topRight, frameRect.topRight + const Offset(-len, 0), corner);
    canvas.drawLine(frameRect.topRight, frameRect.topRight + const Offset(0, len), corner);
    // Bottom-left
    canvas.drawLine(frameRect.bottomLeft, frameRect.bottomLeft + const Offset(len, 0), corner);
    canvas.drawLine(frameRect.bottomLeft, frameRect.bottomLeft + const Offset(0, -len), corner);
    // Bottom-right
    canvas.drawLine(frameRect.bottomRight, frameRect.bottomRight + const Offset(-len, 0), corner);
    canvas.drawLine(frameRect.bottomRight, frameRect.bottomRight + const Offset(0, -len), corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
