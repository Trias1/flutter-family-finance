class DateFormatter {
  /// Set by the app whenever the language changes ('id' or 'en').
  static String languageCode = 'id';

  static bool get _en => languageCode != 'id';

  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _fullMonthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _daysEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  static const _fullMonths = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  static const _days = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String format(DateTime date) {
    final months = _en ? _monthsEn : _months;
    return '${_two(date.day)} ${months[date.month - 1]} ${date.year}';
  }

  static String formatFull(DateTime date) {
    final days = _en ? _daysEn : _days;
    final months = _en ? _fullMonthsEn : _fullMonths;
    return '${days[date.weekday - 1]}, ${_two(date.day)} ${months[date.month - 1]} ${date.year}';
  }

  static String formatMonth(DateTime date) {
    return '${(_en ? _fullMonthsEn : _fullMonths)[date.month - 1]} ${date.year}';
  }

  static String formatTime(DateTime date) {
    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  static String toIso(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)}';
  }
}
