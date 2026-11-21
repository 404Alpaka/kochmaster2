import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kochmaster/core/theme/app_theme.dart';
import 'package:kochmaster/features/meal_planning/presentation/planning_page.dart';

import 'scroll_helpers.dart';

import 'package:kochmaster/features/meal_planning/data/receipt_reader_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(receiptNativeChannel, null),
  );

  for (final scenario in ['document', 'cancel', 'permission']) {
    testWidgets('Native iPhone import UI: $scenario', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(receiptNativeChannel, (call) async {
        nativeCalls++;
        expect(call.method, 'readReceiptFile');
        if (scenario == 'cancel') return null;
        if (scenario == 'permission') {
          throw PlatformException(
            code: 'camera_permission',
            message: 'Kamerazugriff nicht erlaubt.',
          );
        }
        return {
          'text': 'REWE\nJOGHURT 1,29 B\nSUMME 1,29',
          'name': 'Bon.pdf',
          'fingerprint': 'native-preview',
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const PlanningPage(recipes: [], isDemo: true),
        ),
      );
      await tester.tap(find.text('Vorrat'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Bon importieren · PDF oder Bild'));
      await tester.tap(find.text('Bon importieren · PDF oder Bild'));
      await tester.pumpAndSettle();
      expect(nativeCalls, 1);
      expect(find.textContaining('Web-App verfügbar'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      if (scenario == 'document') {
        expect(find.text('Einkauf erkannt.'), findsOneWidget);
        expect(find.text('JOGHURT'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(
                  FilledButton,
                  '1 Produkt zum Vorrat hinzufügen',
                ),
              )
              .onPressed,
          isNull,
        );
      } else {
        expect(find.text('Dein Vorrat ist noch leer'), findsOneWidget);
        if (scenario == 'permission') {
          expect(find.text('Kamerazugriff nicht erlaubt.'), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
    'PDF import uses native channel and returns document to review',
    () async {
      messenger.setMockMethodCallHandler(receiptNativeChannel, (call) async {
        expect(call.method, 'readReceiptFile');
        expect(call.arguments, {'camera': false});
        return {
          'text': 'REWE\nJOGHURT 1,29 B',
          'name': 'REWE-ebon.pdf',
          'fingerprint': 'receipt-sha256',
        };
      });
      final document = await readReceiptFile();
      expect(document!['name'], 'REWE-ebon.pdf');
      expect(document['text'], contains('JOGHURT'));
    },
  );
  test(
    'document camera and barcode photos use their requested native operation',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(receiptNativeChannel, (call) async {
        calls.add(call);
        return call.method == 'readReceiptFile'
            ? {
                'text': 'JOGHURT 1,29 B',
                'name': 'Bonfoto',
                'fingerprint': 'photo',
              }
            : '4006381333931';
      });
      await readReceiptFile(camera: true);
      expect(await scanProductBarcode(camera: false), '4006381333931');
      expect(calls[0].arguments, {'camera': true});
      expect(calls[1].arguments, {'camera': false});
    },
  );
  test('canceling native picker does not create a receipt', () async {
    messenger.setMockMethodCallHandler(receiptNativeChannel, (_) async => null);
    expect(await readReceiptFile(), isNull);
    expect(await scanProductBarcode(), isNull);
  });
  test(
    'native product lookup returns product data without a web runtime',
    () async {
      messenger.setMockMethodCallHandler(receiptNativeChannel, (call) async {
        expect(call.method, 'lookupProductBarcode');
        expect(call.arguments, {'barcode': '3017620422003'});
        return {'product_name_de': 'Nusscreme', 'quantity': '400 g'};
      });
      expect(
        (await lookupProductBarcode('3017620422003'))!['quantity'],
        '400 g',
      );
    },
  );
  test(
    'permissions and recognition failures keep native error messages',
    () async {
      messenger.setMockMethodCallHandler(
        receiptNativeChannel,
        (_) async => throw PlatformException(
          code: 'camera_permission',
          message: 'Kamerazugriff nicht erlaubt.',
        ),
      );
      await expectLater(
        readReceiptFile(camera: true),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            'Kamerazugriff nicht erlaubt.',
          ),
        ),
      );
    },
  );
  test('an old native app build explains that reinstall is required', () async {
    await expectLater(
      readReceiptFile(),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('neu bauen und installieren'),
        ),
      ),
    );
  });
}
