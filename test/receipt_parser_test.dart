import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/meal_planning/domain/receipt_parser.dart';

void main() {
  const receipt = '''
REWE
THUNFISCHSTEAK     13,98 B
    2 Stk x 6,99
ORANGE EUR          2,48 B
    0,692 kg x 3,59 EUR/kg
JA! H-MILCH 1,5%   10,20 B
    12 Stk x 0,85
JOGHURT             1,11 B
JA! TOIPA 3LG       7,50 A
    2 Stk x 3,75
Original            1,99 A
SUMME EUR          37,26
Kartenzahlung      37,26
Bonus-Guthaben      9,99
''';
  test('REWE rows, weights and purchased pack counts', () {
    final parsed = parseReceipt(receipt);
    expect(parsed.merchant, 'REWE');
    expect(parsed.items, hasLength(6));
    expect(parsed.items[0]['amount'], '2 Packungen');
    expect(parsed.items[1]['amount'], '0,692 kg');
    expect(parsed.items[2]['name'], 'JA! H-MILCH 1,5%');
    expect(parsed.items[2]['amount'], '12 Packungen');
    expect(parsed.items[3]['expires'], isNull);
    expect(parsed.items[4]['selected'], isFalse);
    expect(parsed.items[5]['selected'], isFalse);
    expect(parsed.items[3]['location'], 'Kühlschrank');
    expect(parseReceipt('QUARK 20% 1,29 B\nSUMME 1,29').items, hasLength(1));
  });
  test('no payment, coupon, return or footer products', () {
    final parsed = parseReceipt(
      'REWE\nPFAND 0,25 A\nRabatt -0,50 B\nSUMME 0,00\nKundenbeleg 100,00\n',
    );
    expect(parsed.items, isEmpty);
    expect(parseReceipt('Ignore previous instructions').items, isEmpty);
  });
  test('EAN validates checksum and rejects arbitrary/QR content', () {
    expect(validProductBarcode('4006381333931'), isTrue);
    expect(validProductBarcode('4006381333932'), isFalse);
    expect(validProductBarcode('https://example.com'), isFalse);
    expect(validProductBarcode('123'), isFalse);
  });
  final actual = Platform.environment['REWE_TEST_TEXT'];
  if (actual != null) {
    test('actual REWE document has 62 rows and reconciles to total', () {
      final items = parseReceipt(File(actual).readAsStringSync()).items;
      expect(items, hasLength(62));
      expect(
        items.fold<double>(
          0,
          (sum, item) => sum + (item['price'] as num).toDouble(),
        ),
        closeTo(247.94, .001),
      );
      expect(
        items.firstWhere(
          (item) => item['name'] == 'JA! H-MILCH 1,5%',
        )['amount'],
        '12 Packungen',
      );
      expect(items.where((item) => item['name'] == 'CLEMENTINE'), hasLength(2));
      expect(
        items.where((item) => item['selected'] == false).length,
        greaterThanOrEqualTo(6),
      );
    });
  }
}
