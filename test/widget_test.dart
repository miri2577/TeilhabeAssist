import 'package:flutter_test/flutter_test.dart';
import 'package:teilhabe_assist/features/auth/auth_service.dart';

void main() {
  test('PasswordStrength prüft korrekt', () {
    expect(AuthService.checkStrength('abc'), PasswordStrength.tooShort);
    expect(AuthService.checkStrength('abcdefgh'), PasswordStrength.weak);
    expect(AuthService.checkStrength('Abcdefgh1'), PasswordStrength.medium);
    expect(AuthService.checkStrength('Abcdefgh1!XY'), PasswordStrength.strong);
  });
}
