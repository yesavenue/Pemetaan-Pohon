import 'dart:async';
import 'dart:io';
import 'package:pemetaan_pohon/utils/session_feed.dart';

void check(bool value, String message) {
  if (!value) {
    throw StateError(message);
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
Future<void> main() async {
  var loads = 0;
  final sources = <StreamController<int>>[];
  final feed = SessionFeed<int>(() {
    loads++;
    final controller = StreamController<int>();
    sources.add(controller);
    return controller.stream;
  });
  final first = <int>[];
  final errors = <Object>[];
  final one = feed.watch().listen(first.add, onError: errors.add);
  sources.single.add(7);
  await tick();
  final second = <int>[];
  final two = feed.watch().listen(second.add, onError: errors.add);
  await tick();
  check(
    loads == 1 && second.single == 7,
    'New view must replay without another upstream',
  );
  sources.single.add(8);
  await tick();
  check(first.last == 8 && second.last == 8, 'Both views must receive updates');
  sources.single.addError(StateError('offline'));
  await tick();
  check(
    feed.latest == null && errors.length == 2,
    'Error invalidates cached snapshot',
  );
  await Future.wait([feed.reload(), feed.reload()]);
  check(
    loads == 2 && !sources.first.hasListener,
    'Concurrent retry creates one source',
  );
  sources.last.add(9);
  await tick();
  check(
    first.last == 9 && second.last == 9,
    'Retry must refresh existing consumers',
  );
  await two.cancel();
  check(sources.last.hasListener, 'Remaining view keeps source alive');
  feed.dispose();
  await tick();
  check(
    !sources.last.hasListener && feed.latest == null,
    'Dispose cancels source and clears data',
  );
  await one.cancel();
  for (final source in sources) {
    await source.close();
  }
  stdout.writeln(
    'PASS: shared source, replay, update, error, retry, cancellation, session disposal.',
  );
}