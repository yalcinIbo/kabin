/// Deneme ve 3D işlerinin durumu.
enum JobStatus {
  queued('queued'),
  processing('processing'),
  done('done'),
  failed('failed');

  const JobStatus(this.value);
  final String value;

  bool get isActive => this == JobStatus.queued || this == JobStatus.processing;
  bool get isTerminal => !isActive;

  String get labelTr => switch (this) {
    JobStatus.queued => 'Sırada',
    JobStatus.processing => 'Hazırlanıyor',
    JobStatus.done => 'Hazır',
    JobStatus.failed => 'Başarısız',
  };

  static JobStatus fromValue(String? value) => JobStatus.values.firstWhere((e) => e.value == value, orElse: () => JobStatus.queued);
}
