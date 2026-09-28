/// İşin o anki aşaması; ilerleme ekranında Türkçe gösterilir.
enum JobStage {
  starting('starting', 'Başlıyor'),
  preparing('preparing', 'Görseller hazırlanıyor'),
  tryon('tryon', 'Kıyafet giydiriliyor'),
  multiview('multiview', 'Yan ve arka görünüm oluşturuluyor'),
  advice('advice', 'Stil önerisi hazırlanıyor'),
  saving('saving', 'Kaydediliyor'),
  segment('segment', 'Arka plan temizleniyor'),
  generate('generate', '3D model oluşturuluyor'),
  checking('checking', 'Selfie kontrol ediliyor'),
  generating('generating', 'Stüdyo fotoğrafı oluşturuluyor'),
  verifying('verifying', 'Kalite kontrol ediliyor'),
  unknown('unknown', 'İşleniyor');

  const JobStage(this.value, this.labelTr);
  final String value;
  final String labelTr;

  static JobStage? fromValue(String? value) {
    if (value == null) return null;
    return JobStage.values.firstWhere((e) => e.value == value, orElse: () => JobStage.unknown);
  }
}
