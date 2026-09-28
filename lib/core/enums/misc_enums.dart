enum LedgerType {
  grant('grant', 'Hediye'),
  debit('debit', 'Harcama'),
  refund('refund', 'İade'),
  purchase('purchase', 'Satın alma');

  const LedgerType(this.value, this.labelTr);
  final String value;
  final String labelTr;

  static LedgerType fromValue(String? value) => LedgerType.values.firstWhere((e) => e.value == value, orElse: () => LedgerType.grant);
}

enum ViewAngle {
  front('front', 'Ön'),
  side('side', 'Yan'),
  back('back', 'Arka');

  const ViewAngle(this.value, this.labelTr);
  final String value;
  final String labelTr;

  static ViewAngle fromValue(String? value) => ViewAngle.values.firstWhere((e) => e.value == value, orElse: () => ViewAngle.front);
}

/// Yönetici karşılaştırma modunda seçilebilen sağlayıcılar.
enum TryOnProviderChoice {
  fashn('fashn', 'FASHN'),
  vertex('vertex', 'Vertex'),
  gemini('gemini', 'Gemini'),
  both('both', 'FASHN + Vertex');

  const TryOnProviderChoice(this.value, this.labelTr);
  final String value;
  final String labelTr;
}
