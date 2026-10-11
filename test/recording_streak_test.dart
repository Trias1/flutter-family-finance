import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/features/settings/presentation/widgets/profile_sections.dart';

void main() {
  final today = DateTime(2026, 10, 11, 20, 0);

  test('counts back from today', () {
    expect(
      recordingStreak([
        DateTime(2026, 10, 11, 9),
        DateTime(2026, 10, 10, 22),
        DateTime(2026, 10, 9, 7),
        DateTime(2026, 10, 7, 7),
      ], today),
      3,
    );
  });

  test('still counts when today has nothing yet', () {
    expect(
      recordingStreak([DateTime(2026, 10, 10), DateTime(2026, 10, 9)], today),
      2,
    );
  });

  test('a gap of two days ends it', () {
    expect(recordingStreak([DateTime(2026, 10, 9)], today), 0);
    expect(recordingStreak(const [], today), 0);
  });

  test('several entries on one day count once, across a month end', () {
    expect(
      recordingStreak([
        DateTime(2026, 11, 1, 8),
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 10, 31, 23),
      ], DateTime(2026, 11, 1, 12)),
      2,
    );
  });
}
