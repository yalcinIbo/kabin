enum BodyType {
  slim('slim', 'İnce'),
  average('average', 'Orta'),
  athletic('athletic', 'Atletik'),
  curvy('curvy', 'Kıvrımlı'),
  plus('plus', 'Büyük beden');

  const BodyType(this.value, this.labelTr);
  final String value;
  final String labelTr;

  static BodyType? fromValue(String? value) {
    if (value == null) return null;
    for (final e in BodyType.values) {
      if (e.value == value) return e;
    }
    return null;
  }
}

enum Gender {
  female('female', 'Kadın'),
  male('male', 'Erkek'),
  unspecified('unspecified', 'Belirtmek istemiyorum');

  const Gender(this.value, this.labelTr);
  final String value;
  final String labelTr;

  static Gender fromValue(String? value) => Gender.values.firstWhere((e) => e.value == value, orElse: () => Gender.unspecified);
}
