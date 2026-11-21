Future<Map<String, dynamic>?> readReceiptFile({bool camera = false}) async =>
    throw UnsupportedError(
      'Der Bon-Import ist aktuell in der Web-App verfügbar.',
    );
Future<String?> scanProductBarcode({bool camera = true}) async =>
    throw UnsupportedError(
      'Der Barcode-Scan ist aktuell in der Web-App verfügbar.',
    );
Future<Map<String, dynamic>?> lookupProductBarcode(String barcode) async =>
    throw UnsupportedError(
      'Die Produktsuche ist aktuell in der Web-App verfügbar.',
    );
