import 'dart:async';

/// Arama girişi, typing göstergesi ve Reels view metrikleri için debounce.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  bool get isActive => _timer?.isActive ?? false;

  void cancel() => _timer?.cancel();

  void dispose() => cancel();
}
