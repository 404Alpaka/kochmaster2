import 'dart:convert';
import 'dart:js_interop';

@JS('miseReadReceipt')
external JSPromise<JSString> _read(JSString mode);
@JS('miseScanBarcode')
external JSPromise<JSString> _scan(JSBoolean camera);
@JS('miseLookupBarcode')
external JSPromise<JSString> _lookup(JSString code);

Future<Map<String, dynamic>?> readReceiptFile({bool camera = false}) async {
  final result = jsonDecode(
    (await _read((camera ? 'camera' : 'file').toJS).toDart).toDart,
  );
  return result == null ? null : Map<String, dynamic>.from(result as Map);
}

Future<String?> scanProductBarcode({bool camera = true}) async {
  final result = jsonDecode((await _scan(camera.toJS).toDart).toDart);
  return result as String?;
}

Future<Map<String, dynamic>?> lookupProductBarcode(String barcode) async {
  final result = jsonDecode((await _lookup(barcode.toJS).toDart).toDart);
  return result == null ? null : Map<String, dynamic>.from(result as Map);
}
