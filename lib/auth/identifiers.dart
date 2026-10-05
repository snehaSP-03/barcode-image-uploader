final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String toE164Phone(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return '';

  if (raw.startsWith('+')) {
    final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '' : '+$digits';
  }

  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '+91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  if (digits.length > 10) return '+$digits';
  return digits.isEmpty ? '' : '+91$digits';
}

bool isEmail(String? value) => _emailRe.hasMatch((value ?? '').trim());

class LoginIdentifier {
  const LoginIdentifier({required this.username, required this.kind});
  final String username;
  final String kind;
}

LoginIdentifier normalizeLoginIdentifier(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('Enter your phone number or email.');
  }

  if (trimmed.contains('@')) {
    if (!isEmail(trimmed)) {
      throw ArgumentError('Enter a valid email address.');
    }
    return LoginIdentifier(username: trimmed.toLowerCase(), kind: 'email');
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 10 && !(digits.length == 12 && digits.startsWith('91'))) {
    throw ArgumentError('Enter a valid 10-digit mobile number or email.');
  }

  return LoginIdentifier(username: toE164Phone(trimmed), kind: 'phone');
}

bool isValidPin(String? pin) => RegExp(r'^\d{4}$').hasMatch(pin ?? '');
