import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

class AccountDataExporter {
  const AccountDataExporter();

  Future<bool> save(Map<String, dynamic> data, Rect origin) async {
    final fileName =
        'mise-daten-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json';
    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Meine mise.-Daten',
        files: [
          XFile.fromData(
            Uint8List.fromList(
              utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
            ),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
        downloadFallbackEnabled: true,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
