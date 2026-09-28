import '../converters.dart';

class BenchmarkRunModel {
  const BenchmarkRunModel({required this.id, this.providers = const [], this.pairCount = 0, this.doneCount = 0, this.createdAt});

  final String id;
  final List<String> providers;
  final int pairCount;
  final int doneCount;
  final DateTime? createdAt;

  bool get isComplete => doneCount >= pairCount;

  factory BenchmarkRunModel.fromMap(Map<String, dynamic> map, String id) => BenchmarkRunModel(
    id: id,
    providers: Converters.toStringList(map['providers']),
    pairCount: Converters.toInt(map['pairCount']),
    doneCount: Converters.toInt(map['doneCount']),
    createdAt: Converters.toDateTime(map['createdAt']),
  );
}

class BenchmarkResultModel {
  const BenchmarkResultModel({this.storagePath, this.ms = 0, this.costUsd = 0, this.error, this.actualProvider});

  final String? storagePath;
  final int ms;
  final double costUsd;
  final String? error;
  final String? actualProvider;

  factory BenchmarkResultModel.fromMap(Map<String, dynamic> map) => BenchmarkResultModel(
    storagePath: map['storagePath'] as String?,
    ms: Converters.toInt(map['ms']),
    costUsd: Converters.toDouble(map['costUsd']),
    error: map['error'] as String?,
    actualProvider: map['actualProvider'] as String?,
  );
}

class BenchmarkPairModel {
  const BenchmarkPairModel({
    required this.id,
    this.status = 'queued',
    this.garmentTitle,
    this.photoThumbPath,
    this.garmentThumbPath,
    this.results = const {},
    this.winner,
  });

  final String id;
  final String status;
  final String? garmentTitle;
  final String? photoThumbPath;
  final String? garmentThumbPath;
  final Map<String, BenchmarkResultModel> results;
  final String? winner;

  bool get isDone => status == 'done';

  factory BenchmarkPairModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = Converters.toMap(map['results']);
    return BenchmarkPairModel(
      id: id,
      status: Converters.toStr(map['status'], 'queued'),
      garmentTitle: map['garmentTitle'] as String?,
      photoThumbPath: map['photoThumbPath'] as String?,
      garmentThumbPath: map['garmentThumbPath'] as String?,
      results: raw.map((k, v) => MapEntry(k, BenchmarkResultModel.fromMap(Converters.toMap(v)))),
      winner: Converters.toMap(map['rating'])['winner'] as String?,
    );
  }
}
