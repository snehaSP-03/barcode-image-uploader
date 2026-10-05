import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/auth_store.dart';
import '../auth/errors.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _pinController = TextEditingController();
  final _identifierFocus = FocusNode();
  final _pinFocus = FocusNode();

  AnimationController? _entrance;
  Animation<double>? _fadeHero;
  Animation<Offset>? _slideForm;
  Animation<double>? _fadeForm;

  bool _loading = false;
  bool _obscurePin = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  /// Hot reload does not re-run [initState]; rebuild animation fields safely.
  @override
  void reassemble() {
    super.reassemble();
    _setupAnimations();
  }

  void _setupAnimations() {
    _entrance?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entrance = controller;
    _fadeHero = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _slideForm = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _fadeForm = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    _entrance?.dispose();
    _identifierController.dispose();
    _pinController.dispose();
    _identifierFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthStore.instance.login(
        identifier: _identifierController.text,
        pin: _pinController.text,
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final fadeHero = _fadeHero;
    final slideForm = _slideForm;
    final fadeForm = _fadeForm;

    // Guard against hot-reload races before animations are ready.
    if (fadeHero == null || slideForm == null || fadeForm == null) {
      return const Scaffold(
        body: ColoredBox(
          color: Color(0xFF0B2E1F),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(child: _LoginBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeTransition(
                            opacity: fadeHero,
                            child: const _BrandHero(),
                          ),
                          const SizedBox(height: 28),
                          SlideTransition(
                            position: slideForm,
                            child: FadeTransition(
                              opacity: fadeForm,
                              child: _LoginFormPanel(
                                identifierController: _identifierController,
                                pinController: _pinController,
                                identifierFocus: _identifierFocus,
                                pinFocus: _pinFocus,
                                loading: _loading,
                                obscurePin: _obscurePin,
                                error: _error,
                                onTogglePin: () => setState(() => _obscurePin = !_obscurePin),
                                onSubmit: _submit,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B2E1F),
            Color(0xFF1F6F4A),
            Color(0xFF163D2C),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BarcodeWashPainter()),
          // Soft light bloom — kept subtle, not a neon glow.
          Positioned(
            top: -80,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3FAE78).withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeWashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    final rng = math.Random(7);
    var x = size.width * 0.58;
    while (x < size.width + 20) {
      final w = 1.5 + rng.nextDouble() * 3.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height * 0.08, w, size.height * 0.42),
          const Radius.circular(1),
        ),
        paint,
      );
      x += w + 2 + rng.nextDouble() * 5;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BHIMA',
            style: GoogleFonts.fraunces(
              fontSize: 52,
              height: 0.95,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Barcode Photos',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Look up a catalog product and capture its photos.',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.identifierController,
    required this.pinController,
    required this.identifierFocus,
    required this.pinFocus,
    required this.loading,
    required this.obscurePin,
    required this.error,
    required this.onTogglePin,
    required this.onSubmit,
  });

  final TextEditingController identifierController;
  final TextEditingController pinController;
  final FocusNode identifierFocus;
  final FocusNode pinFocus;
  final bool loading;
  final bool obscurePin;
  final String? error;
  final VoidCallback onTogglePin;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.dmSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in',
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ops or Admin account required.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Text('Phone or email', style: labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: identifierController,
            focusNode: identifierFocus,
            style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.text),
            decoration: _fieldDecoration(
              hint: '10-digit mobile or email',
              prefix: Icons.person_outline_rounded,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !loading,
            onSubmitted: (_) => pinFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          Text('PIN', style: labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: pinController,
            focusNode: pinFocus,
            style: GoogleFonts.dmSans(
              fontSize: 20,
              letterSpacing: 8,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            decoration: _fieldDecoration(
              hint: '••••',
              prefix: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: loading ? null : onTogglePin,
                icon: Icon(
                  obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                ),
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: obscurePin,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !loading,
            onSubmitted: (_) => onSubmit(),
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(
                      'Continue',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(color: AppColors.muted.withValues(alpha: 0.85)),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF4F8F5),
      prefixIcon: Icon(prefix, color: AppColors.primary),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }
}
