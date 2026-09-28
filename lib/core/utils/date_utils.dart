import 'package:intl/intl.dart';

abstract final class AppDateUtils {
  /// "az önce", "5 dakika önce", "3 saat önce", "12 Mart 2026".
  static String timeAgoLong(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(date);
    if (diff.inSeconds < 45) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return formatDate(date, withYear: date.year != current.year);
  }

  static String formatDate(DateTime date, {bool withYear = true}) => DateFormat(withYear ? 'd MMMM yyyy' : 'd MMMM', 'tr_TR').format(date);

  static String formatDateTime(DateTime date) => DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(date);
}
