enum GarmentStatus {
  analyzing('analyzing'),
  ready('ready'),
  failed('failed');

  const GarmentStatus(this.value);
  final String value;

  static GarmentStatus fromValue(String? value) =>
      GarmentStatus.values.firstWhere((e) => e.value == value, orElse: () => GarmentStatus.analyzing);
}

enum GarmentCategory {
  tops('tops', 'Üst giyim'),
  bottoms('bottoms', 'Alt giyim'),
  onePieces('one-pieces', 'Tulum'),
  dresses('dresses', 'Elbise'),
  shoes('shoes', 'Ayakkabı'),
  other('other', 'Diğer');

  const GarmentCategory(this.value, this.labelTr);
  final String value;
  final String labelTr;

  /// Sunucudaki `isTryOnCategory` ile aynı.
  bool get isTryOnSupported =>
      this == GarmentCategory.tops ||
      this == GarmentCategory.bottoms ||
      this == GarmentCategory.onePieces ||
      this == GarmentCategory.dresses;

  static GarmentCategory fromValue(String? value) =>
      GarmentCategory.values.firstWhere((e) => e.value == value, orElse: () => GarmentCategory.other);
}

enum GarmentPhotoType {
  flatLay('flat-lay', 'Düz / askıda'),
  model('model', 'Üzerinde giyilmiş'),
  mannequin('mannequin', 'Mankende'),
  screenshot('screenshot', 'Ekran görüntüsü');

  const GarmentPhotoType(this.value, this.labelTr);
  final String value;
  final String labelTr;

  static GarmentPhotoType fromValue(String? value) =>
      GarmentPhotoType.values.firstWhere((e) => e.value == value, orElse: () => GarmentPhotoType.flatLay);
}
