import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts plus addresses and long TLDs', () {
      expect(Validators.email('budi+keluarga@example.co.id'), isNull);
      expect(Validators.email('ani@mail.digital'), isNull);
    });

    test('rejects malformed addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('budi@'), isNotNull);
      expect(Validators.email('budi example.com'), isNotNull);
    });
  });

  group('Validators.password (sign in)', () {
    test('only requires a value, so older short passwords still work', () {
      expect(Validators.password('abc123'), isNull);
      expect(Validators.password(''), isNotNull);
    });
  });

  group('Validators.newPassword', () {
    test('requires 8+ characters with letters and digits', () {
      expect(Validators.newPassword('abc12345'), isNull);
      expect(Validators.newPassword('abc123'), isNotNull);
      expect(Validators.newPassword('abcdefgh'), isNotNull);
      expect(Validators.newPassword('12345678'), isNotNull);
    });
  });
}
