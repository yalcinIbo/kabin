import 'package:flutter/material.dart';

/// Kabin paleti: atölye ve moda dergisi hissi.
/// Fildişi kâğıt zemin, koyu mürdüm kadife (kabin perdesi), kiremit vurgu. Yalnızca buradaki renkler kullanılır.
abstract final class AppColors {
  // Kâğıt ve kum tonları (açık tema zemini)
  static const Color ivory = Color(0xFFFBF7F2);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color sand50 = Color(0xFFF7F1EA);
  static const Color sand100 = Color(0xFFF1E9DF);
  static const Color sand200 = Color(0xFFE6DACC);
  static const Color sand300 = Color(0xFFD3C3B1);

  // Mürekkep (metin)
  static const Color ink = Color(0xFF1C1422);
  static const Color ink2 = Color(0xFF4E4453);
  static const Color ink3 = Color(0xFF8A7F8D);

  // Kadife mürdüm (perde, birincil)
  static const Color plum950 = Color(0xFF160C1D);
  static const Color plum900 = Color(0xFF2B1838);
  static const Color plum800 = Color(0xFF3A2149);
  static const Color plum700 = Color(0xFF4F2D63);
  static const Color plum500 = Color(0xFF7F55A0);
  static const Color plum300 = Color(0xFFC3A9DA);
  static const Color plum100 = Color(0xFFEFE6F4);

  // Kiremit vurgu
  static const Color terracotta = Color(0xFFD5603D);
  static const Color terracottaDeep = Color(0xFFB4492A);
  static const Color terracottaSoft = Color(0xFFF7E0D6);
  static const Color blush = Color(0xFFF3D9CF);

  // İnce altın çizgi (etiket, ayrıntı)
  static const Color brass = Color(0xFFB8925A);
  static const Color brassLight = Color(0xFFE2C48E);
  static const Color brassDark = Color(0xFF7E6135);

  // Koyu tema
  static const Color night = Color(0xFF120C16);
  static const Color night2 = Color(0xFF1B1321);
  static const Color night3 = Color(0xFF261B2E);
  static const Color night4 = Color(0xFF34273D);
  static const Color moon = Color(0xFFF3ECE3);
  static const Color moon2 = Color(0xFFBDB2BF);

  // Semantik
  static const Color error = Color(0xFFC8364A);
  static const Color errorSoft = Color(0xFFF8DDE1);
  static const Color success = Color(0xFF2E8B63);
  static const Color successSoft = Color(0xFFDDF1E7);
  static const Color warning = Color(0xFFC98A12);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  /// Görsel altı karartma (etiketler okunaklı olsun).
  static const Color plumShade = Color(0x8C160C1D);

  // Koyu tema yardımcıları
  static const Color terracottaNight = Color(0xFF4A2418);
  static const Color errorNight = Color(0xFFFF7A8C);
  static const Color errorNightContainer = Color(0xFF4A1820);
  static const Color errorNightOn = Color(0xFFFFC2CA);

  /// Perde kadifesi: koyudan açığa kıvrım gradyanı.
  static const List<Color> velvet = [plum950, plum900, plum700, plum900, plum950];
}
