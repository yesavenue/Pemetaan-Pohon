import 'dart:io';
import 'package:pemetaan_pohon/utils/surveyor_provisioning.dart';

Future<void> main() async {
  for (final scenario in [
    'success',
    'auth-fail',
    'rollback',
    'unknown',
    'committed',
    'rollback-fail',
    'cleanup-fail',
  ]) {
    var cleaned = 0, deleted = 0, writes = 0;
    final result = await provisionSurveyor(
      createAccount: () async {
        if (scenario == 'auth-fail') throw StateError('auth');
        return 'new-uid';
      },
      writeProfile: (_) async {
        writes++;
        if (scenario != 'success' && scenario != 'cleanup-fail') {
          throw StateError('write');
        }
      },
      profileExistsOnServer: (_) async {
        if (scenario == 'unknown') throw StateError('offline');
        return scenario == 'committed';
      },
      deleteNewAccount: () async {
        deleted++;
        if (scenario == 'rollback-fail') throw StateError('delete');
      },
      cleanup: () async {
        cleaned++;
        if (scenario == 'cleanup-fail') throw StateError('cleanup');
      },
    );
    if (cleaned != 1) throw StateError('Cleanup missing: $scenario');
    final success = ['success', 'committed', 'cleanup-fail'].contains(scenario);
    if ((result == null) != success) {
      throw StateError('Wrong outcome: $scenario');
    }
    final shouldDelete = ['rollback', 'rollback-fail'].contains(scenario);
    if (deleted != (shouldDelete ? 1 : 0)) {
      throw StateError('Unsafe rollback: $scenario');
    }
    if (scenario == 'auth-fail' && writes != 0) {
      throw StateError('Unexpected write');
    }
  }
  stdout.writeln(
    'PASS: success, auth failure, rollback, unknown/committed profile, rollback failure, cleanup failure.',
  );
}