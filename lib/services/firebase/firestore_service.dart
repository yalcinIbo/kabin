import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/errors.dart';
import '../../core/utils/paged_state.dart';

typedef DocData = Map<String, dynamic>;
typedef DocMapper<T> = T Function(DocData data, String id);

/// Cloud Firestore erişim katmanı. Repository'ler yalnızca bu sınıfı kullanır;
/// tüm hatalar [AppException]'a çevrilir ve sayfalama tek noktada yapılır.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<DocData> collection(String path) => _db.collection(path);
  DocumentReference<DocData> doc(String path) => _db.doc(path);
  CollectionReference<DocData> collectionGroup(String id) => _db.collectionGroup(id) as CollectionReference<DocData>;

  /// Yeni belge id'si üretir (medya yolu için önceden id gerekir).
  String newId(String collectionPath) => _db.collection(collectionPath).doc().id;

  FieldValue get serverTimestamp => FieldValue.serverTimestamp();
  FieldValue increment(num value) => FieldValue.increment(value);
  FieldValue arrayUnion(List<Object?> values) => FieldValue.arrayUnion(values);
  FieldValue arrayRemove(List<Object?> values) => FieldValue.arrayRemove(values);
  FieldValue get deleteField => FieldValue.delete();
  Timestamp now() => Timestamp.now();

  Future<DocumentSnapshot<DocData>> getDoc(String path, {bool fromCache = false}) =>
      guard(() => _db.doc(path).get(fromCache ? const GetOptions(source: Source.cache) : null));

  Future<T?> getTyped<T>(String path, DocMapper<T> mapper) => guard(() async {
    final snap = await _db.doc(path).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return mapper(data, snap.id);
  });

  Stream<T?> watchTyped<T>(String path, DocMapper<T> mapper) => _db
      .doc(path)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return mapper(data, snap.id);
      })
      .handleError((Object e) => throw ErrorMapper.map(e));

  Future<void> setDoc(String path, DocData data, {bool merge = false}) => guard(() => _db.doc(path).set(data, SetOptions(merge: merge)));

  Future<void> updateDoc(String path, DocData data) => guard(() => _db.doc(path).update(data));

  Future<void> deleteDoc(String path) => guard(() => _db.doc(path).delete());

  Future<bool> exists(String path) => guard(() async => (await _db.doc(path).get()).exists);

  Future<T> runTransaction<T>(Future<T> Function(Transaction tx) handler) => guard(() => _db.runTransaction<T>(handler));

  WriteBatch batch() => _db.batch();

  Future<void> commitBatch(WriteBatch batch) => guard(batch.commit);

  Future<List<T>> getList<T>(Query<DocData> query, DocMapper<T> mapper) => guard(() async {
    final snap = await query.get();
    return snap.docs.map((d) => mapper(d.data(), d.id)).toList();
  });

  Stream<List<T>> watchList<T>(Query<DocData> query, DocMapper<T> mapper) => query
      .snapshots()
      .map((snap) => snap.docs.map((d) => mapper(d.data(), d.id)).toList())
      .handleError((Object e) => throw ErrorMapper.map(e));

  /// Cursor tabanlı sayfa. [cursor] önceki sayfanın döndürdüğü opak nesnedir
  /// (son DocumentSnapshot). Sorgu `orderBy` içermelidir.
  Future<PageResult<T>> getPage<T>(Query<DocData> query, {required int limit, Object? cursor, required DocMapper<T> mapper}) =>
      guard(() async {
        var q = query.limit(limit);
        if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
        final snap = await q.get();
        final items = snap.docs.map((d) => mapper(d.data(), d.id)).toList();
        return PageResult<T>(items: items, cursor: snap.docs.isEmpty ? cursor : snap.docs.last, hasMore: snap.docs.length >= limit);
      });

  Future<int> count(Query<DocData> query) => guard(() async {
    final agg = await query.count().get();
    return agg.count ?? 0;
  });

  /// Tüm Firestore çağrılarını sarar; hataları uygulama hatasına çevirir.
  Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
