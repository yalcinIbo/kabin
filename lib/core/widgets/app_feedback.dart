import 'package:flutter/material.dart';

/// SnackBar ve onay diyaloğu yardımcıları. Ekranlar hata mesajını buradan gösterir.
abstract final class AppFeedback {
  static void showError(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: scheme.onError)),
          backgroundColor: scheme.error,
        ),
      );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static void showInfo(BuildContext context, String message) => showSuccess(context, message);

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Onayla',
    String cancelLabel = 'Vazgeç',
    bool destructive = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive ? TextButton.styleFrom(foregroundColor: scheme.error) : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
