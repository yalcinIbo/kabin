import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore <-> Dart dönüşüm yardımcıları. Modeller yalnızca bunları kullanır.
abstract final class Converters {
  static DateTime? toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime toDateTimeOrNow(Object? value) => toDateTime(value) ?? DateTime.now();

  static Timestamp? toTimestamp(DateTime? value) => value == null ? null : Timestamp.fromDate(value);

  static int toInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double toDouble(Object? value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return fallback;
  }

  static bool toBool(Object? value, [bool fallback = false]) => value is bool ? value : fallback;

  static String toStr(Object? value, [String fallback = '']) => value is String ? value : fallback;

  static List<String> toStringList(Object? value) => value is Iterable ? value.whereType<String>().toList() : const [];

  static Map<String, dynamic> toMap(Object? value) => value is Map ? Map<String, dynamic>.from(value) : const {};

  static List<Map<String, dynamic>> toMapList(Object? value) => value is Iterable ? value.whereType<Map>().map(toMap).toList() : const [];
}
