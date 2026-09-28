import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../../core/errors/errors.dart';

/// Sistem paylaşım sayfası.
class ShareService {
  Future<void> shareFile(File file, {String? text, String mimeType = 'image/jpeg'}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          text: text,
        ),
      );
    } catch (e) {
      throw MediaException('Paylaşım açılamadı.', cause: e);
    }
  }
}
