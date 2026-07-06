import 'package:flutter_test/flutter_test.dart';
import 'package:gem_scramble/core/result.dart';

void main() {
  group('Result', () {
    test('Success exposes value and reports success', () {
      const Result<int> result = Success(42);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);
    });

    test('Failure exposes message and reports failure', () {
      const Result<int> result = Failure('boom');
      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, 'boom');
    });

    test('when dispatches to the correct branch', () {
      const Result<int> ok = Success(1);
      const Result<int> err = Failure('nope');

      expect(ok.when(success: (v) => 'v$v', failure: (m) => 'e$m'), 'v1');
      expect(err.when(success: (v) => 'v$v', failure: (m) => 'e$m'), 'enope');
    });

    test('map transforms success and preserves failure', () {
      const Result<int> ok = Success(2);
      const Result<int> err = Failure('bad');

      expect(ok.map((v) => v * 10).valueOrNull, 20);
      expect(err.map((v) => v * 10).errorOrNull, 'bad');
    });
  });
}
