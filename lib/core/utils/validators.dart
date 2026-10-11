class Validators {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email tidak boleh kosong';
    if (!_emailPattern.hasMatch(email)) return 'Email tidak valid';
    return null;
  }

  /// For signing in: existing accounts may predate the current password rule.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
    return null;
  }

  /// For registering or changing a password.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
    if (value.length < 8) return 'Password minimal 8 karakter';
    if (value.length > 128) return 'Password maksimal 128 karakter';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Password harus berisi huruf dan angka';
    }
    return null;
  }

  static String? required(String? value, [String field = 'Field']) {
    if (value == null || value.isEmpty) return '$field tidak boleh kosong';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) return 'Nominal tidak boleh kosong';
    final number = double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    if (number == null || number <= 0) return 'Nominal harus lebih dari 0';
    return null;
  }
}
