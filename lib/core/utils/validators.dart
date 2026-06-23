class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
    if (value.length < 6) return 'Password minimal 6 karakter';
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
