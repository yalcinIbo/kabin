import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/models/model3d/model3d_model.dart';
import 'package:kabin/models/user/user_model.dart';

/// Riverpod, yeni değer eskisine `==` ise dinleyicileri uyarmaz. Modeller alanların bir kısmını
/// karşılaştıran `==` tanımlarsa (ör. yalnız `status`), `refunded` gibi sonradan yazılan alanlar ekrana ulaşmaz.
void main() {
  test('3D işi: yalnız refunded değişen anlık görüntü dinleyiciye ulaşır', () async {
    final controller = StreamController<Model3DModel?>();
    final provider = StreamProvider<Model3DModel?>((ref) => controller.stream);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final seen = <bool>[];
    container.listen(provider, (_, next) {
      final m = next.value;
      if (m != null) seen.add(m.refunded);
    }, fireImmediately: true);

    final failed = {
      'status': 'failed',
      'error': {'code': 'provider-failed', 'messageTr': 'Kota doldu'},
    };
    controller.add(Model3DModel.fromMap(failed, 'm1'));
    await Future<void>.delayed(Duration.zero);
    controller.add(Model3DModel.fromMap({...failed, 'refunded': true}, 'm1'));
    await Future<void>.delayed(Duration.zero);

    expect(seen, [false, true]);
    await controller.close();
  });

  test('kullanıcı: yalnız ölçüleri değişen belge farklı değer sayılır', () {
    final base = {'displayName': 'Test', 'email': 't@kabin.dev', 'credits': 10};
    final a = UserModel.fromMap(base, 'u1');
    final b = UserModel.fromMap({...base, 'heightCm': 172}, 'u1');
    expect(a == b, isFalse);
  });
}
