enum PhotoSource {
  upload('upload'),
  generated('generated');

  const PhotoSource(this.value);
  final String value;

  static PhotoSource fromValue(String? value) => PhotoSource.values.firstWhere((e) => e.value == value, orElse: () => PhotoSource.upload);
}

enum PhotoStatus {
  pending('pending'),
  processing('processing'),
  ready('ready'),
  rejected('rejected'),
  failed('failed');

  const PhotoStatus(this.value);
  final String value;

  bool get isBusy => this == PhotoStatus.pending || this == PhotoStatus.processing;

  String get labelTr => switch (this) {
    PhotoStatus.pending => 'Bekliyor',
    PhotoStatus.processing => 'Hazırlanıyor',
    PhotoStatus.ready => 'Hazır',
    PhotoStatus.rejected => 'Uygun değil',
    PhotoStatus.failed => 'Başarısız',
  };

  static PhotoStatus fromValue(String? value) => PhotoStatus.values.firstWhere((e) => e.value == value, orElse: () => PhotoStatus.pending);
}
