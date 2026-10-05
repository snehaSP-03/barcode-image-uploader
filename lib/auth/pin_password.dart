/// Maps a 4-digit PIN to the Cognito password.
/// Must match bhima-mart-customer / store console mapping.
const List<String> _kParts = ['Bh', 'ima', '!'];

String _prefix() => _kParts.join();

String pinToCognitoPassword(String? pin) {
  final digits = (pin ?? '').replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^\d{4}$').hasMatch(digits)) {
    throw ArgumentError('PIN must be exactly 4 digits.');
  }
  return '${_prefix()}$digits';
}
