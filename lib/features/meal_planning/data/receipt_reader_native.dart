import 'package:flutter/services.dart';

const receiptNativeChannel = MethodChannel('kochmaster/receipt_reader');

Future<T?> _native<T>(String method, Map<String, Object?> arguments) async {
  try {
    return await receiptNativeChannel.invokeMethod<T>(method, arguments);
  } on MissingPluginException {
    throw UnsupportedError(
      'Diese App-Version enthält die native Bon-Erkennung noch nicht. Bitte die iPhone-App vollständig neu bauen und installieren.',
    );
  }
}

Future<Map<String, dynamic>?> _nativeMap(
  String method,
  Map<String, Object?> arguments,
) async {
  final result = await _native<Map<dynamic, dynamic>>(method, arguments);
  return result == null ? null : Map<String, dynamic>.from(result);
}

Future<Map<String, dynamic>?> readReceiptFile({bool camera = false}) =>
    _nativeMap('readReceiptFile', {'camera': camera});
Future<String?> scanProductBarcode({bool camera = true}) =>
    _native<String>('scanProductBarcode', {'camera': camera});
Future<Map<String, dynamic>?> lookupProductBarcode(String barcode) =>
    _nativeMap('lookupProductBarcode', {'barcode': barcode});
