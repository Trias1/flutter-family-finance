class DateFormatter {
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
    return '${_two(date.day)} ${_months[date.month - 1]} ${date.year}';
  }

  static String formatFull(DateTime date) {
    return '${_days[date.weekday - 1]}, ${_two(date.day)} ${_fullMonths[date.month - 1]} ${date.year}';
  }

  static String formatMonth(DateTime date) {
    return '${_fullMonths[date.month - 1]} ${date.year}';
  }

  static String formatTime(DateTime date) {
    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  static String toIso(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)}';
  }
}
