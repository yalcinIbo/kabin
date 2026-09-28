import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/constants/app_constants.dart';
import 'package:kabin/core/enums/enums.dart';
import 'package:kabin/models/models.dart';

void main() {
  group('TryOnJobModel', () {
    test('sunucu belgesini çözer: sonuçlar, stil tavsiyesi, hata', () {
      final job = TryOnJobModel.fromMap({
        'status': 'done',
        'stage': null,
        'progress': 1,
        'photoId': 'p1',
        'garmentId': 'g1',
        'garmentInfo': {'titleTr': 'Lacivert tişört'},
        'options': {'multiView': true},
        'cost': 2,
        'refundedAmount': 1,
        'results': [
          {'provider': 'fashn', 'angle': 'back', 'storagePath': 'a/back.jpg', 'width': 768, 'height': 1024},
          {'provider': 'fashn', 'angle': 'front', 'storagePath': 'a/front.jpg', 'width': 768, 'height': 1024},
        ],
        'styleAdvice': {
          'fitTr': 'İyi',
          'sizeAdviceTr': 'M',
          'tipsTr': ['Kot ile'],
          'occasionTr': 'günlük',
        },
        'model3dRequestId': 'm1',
        'multiViewFailed': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 25)),
      }, 'j1');
      expect(job.isDone, isTrue);
      expect(job.title, 'Lacivert tişört');
      expect(job.multiView, isTrue);
      expect(job.front?.storagePath, 'a/front.jpg');
      expect(job.front?.aspectRatio, 0.75);
      expect(job.styleAdvice?.tipsTr, ['Kot ile']);
      expect(job.activeModel3dId, 'm1');
      expect(job.createdAt, DateTime(2026, 9, 25));
    });

    test('başarısız işte hata ve iade bilgisi', () {
      final job = TryOnJobModel.fromMap({
        'status': 'failed',
        'error': {'code': 'provider-failed', 'messageTr': 'Servis yoğun.'},
        'refunded': true,
      }, 'j2');
      expect(job.status, JobStatus.failed);
      expect(job.status.isTerminal, isTrue);
      expect(job.error?.messageTr, 'Servis yoğun.');
      expect(job.refunded, isTrue);
      expect(job.title, 'Deneme');
    });
  });

  group('Garment', () {
    test('analiz rengi ve deneme desteği', () {
      final g = GarmentModel.fromMap({
        'status': 'ready',
        'storagePath': 'users/u/garments/g/original.jpg',
        'analysis': {'category': 'dresses', 'dominantColorHex': '#1e3a8a', 'titleTr': 'Elbise', 'garmentPhotoType': 'model'},
      }, 'g');
      expect(g.canTryOn, isTrue);
      expect(g.analysis!.color.toARGB32(), 0xFF1E3A8A);
      expect(g.analysis!.garmentPhotoType, GarmentPhotoType.model);
      final shoes = GarmentModel.fromMap({
        'status': 'ready',
        'storagePath': 'x',
        'analysis': {'category': 'shoes'},
      }, 's');
      expect(shoes.canTryOn, isFalse);
    });

    test('toMap kurallarla uyumlu alanları üretir', () {
      const a = GarmentAnalysisModel(category: GarmentCategory.tops, titleTr: 'Gömlek', garmentPhotoType: GarmentPhotoType.flatLay);
      final map = a.copyWith(category: GarmentCategory.onePieces).toMap();
      expect(map['category'], 'one-pieces');
      expect(map['garmentPhotoType'], 'flat-lay');
      expect(map['titleTr'], 'Gömlek');
    });
  });

  group('User & consent', () {
    test('rıza sürümü kontrol edilir', () {
      final user = UserModel.fromMap({
        'credits': 7,
        'heightCm': 172,
        'bodyType': 'athletic',
        'consent': {'kvkkVersion': AppConstants.kvkkVersion, 'kvkkAccepted': true, 'aiTransferAccepted': true},
      }, 'u1');
      expect(user.credits, 7);
      expect(user.measurements.bodyType, BodyType.athletic);
      expect(user.consent!.isValidFor(AppConstants.kvkkVersion), isTrue);
      expect(user.consent!.isValidFor('2020-01'), isFalse);
      expect(user.toCreateMap()['credits'], 0);
    });
  });

  test('fiyatlandırma varsayılanları ve maliyet', () {
    const p = PricingModel();
    expect(p.tryOnCost(multiView: true), 2);
    expect(PricingModel.fromMap({'tryon': 3, 'multiView': 2}).tryOnCost(multiView: true), 5);
    expect(PricingModel.fromMap(null).model3d, 5);
  });

  test('defter kaydı açıklaması', () {
    final e = LedgerEntryModel.fromMap({'type': 'refund', 'amount': 2, 'balanceAfter': 10, 'jobType': 'tryon'}, 'r');
    expect(e.descriptionTr, 'Deneme · iade');
    final w = LedgerEntryModel.fromMap({'type': 'grant', 'amount': 10, 'balanceAfter': 10, 'note': 'Hoş geldin kredisi'}, 'welcome');
    expect(w.descriptionTr, 'Hoş geldin kredisi');
  });
}
