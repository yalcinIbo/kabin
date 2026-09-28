import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/screens/settings/delete_account_screen.dart';

void main() {
  test('SİL onayı Türkçe büyük/küçük harf farklarını kabul eder', () {
    for (final ok in ['SİL', 'sil', 'SIL', 'sıl', ' Sil ', 'SıL']) {
      expect(isDeleteConfirmation(ok), isTrue, reason: ok);
    }
    for (final bad in ['', 'SILL', 'sile', 'delete']) {
      expect(isDeleteConfirmation(bad), isFalse, reason: bad);
    }
  });
}
