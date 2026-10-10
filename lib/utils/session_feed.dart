import 'dart:async';

/// One upstream subscription per owner, with replay for newly opened views.
/// Dispose with the session; never store private data in a global singleton.
class SessionFeed<T> {
  final Stream<T> Function() load;
  SessionFeed(this.load);
  final _listeners = <MultiStreamController<T>>{};
  StreamSubscription<T>? _subscription;
  T? _latest;
  bool _hasValue = false, _started = false, _disposed = false;
  Object? _error;
  StackTrace? _stack;
  int _generation = 0;
  bool _reloading = false;
  T? get latest => _error == null && _hasValue ? _latest : null;

  Stream<T> watch() => Stream<T>.multi((sink) {
    if (_disposed) {
      sink.close();
      return;
    }
    _listeners.add(sink);
    sink.onCancel = () {
      _listeners.remove(sink);
    };
    if (_error != null) {
      sink.addError(_error!, _stack);
    } else if (_hasValue) {
      sink.add(_latest as T);
    }
    if (!_started) {
      _start();
    }
  });

  void _start() {
    if (_disposed) {
      return;
    }
    _started = true;
    final generation = ++_generation;
    try {
      _subscription = load().listen(
        (value) {
          if (_disposed || generation != _generation) {
            return;
          }
          _latest = value;
          _hasValue = true;
          _error = null;
          _stack = null;
          for (final sink in _listeners.toList()) {
            sink.add(value);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (_disposed || generation != _generation) {
            return;
          }
          _fail(error, stack);
        },
        onDone: () {
          if (!_disposed &&
              generation == _generation &&
              !_hasValue &&
              _error == null) {
            _fail(
              StateError('Sumber data selesai tanpa hasil.'),
              StackTrace.current,
            );
          }
        },
      );
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _fail(Object error, StackTrace stack) {
    _error = error;
    _stack = stack;
    _latest = null;
    _hasValue = false;
    for (final sink in _listeners.toList()) {
      sink.addError(error, stack);
    }
  }

  Future<void> reload() async {
    if (_disposed || _reloading) {
      return;
    }
    _reloading = true;
    _error = null;
    _stack = null;
    _latest = null;
    _hasValue = false;
    _generation++;
    final old = _subscription;
    _subscription = null;
    await old?.cancel();
    _reloading = false;
    if (_disposed) {
      return;
    }
    _error = null;
    _stack = null;
    _latest = null;
    _hasValue = false;
    _start();
  }

  /// Used by page retry callbacks; ordinary navigation keeps the live source.
  Stream<T> loadView() {
    if (_error != null) {
      unawaited(reload());
    }
    return watch();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _latest = null;
    _hasValue = false;
    _error = null;
    _stack = null;
    for (final sink in _listeners.toList()) {
      sink.close();
    }
    _listeners.clear();
  }
}