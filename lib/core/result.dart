/// A lightweight typed result used at repository boundaries so failures are
/// explicit values instead of nulls or swallowed exceptions. UI layers can
/// distinguish "empty data" from "request failed" and render accordingly.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  /// Returns the value or null (convenience for callers that only care about
  /// the happy path).
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  /// Returns the failure message or null.
  String? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final message) => message,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(String message) failure,
  }) =>
      switch (this) {
        Success<T>(:final value) => success(value),
        Failure<T>(:final message) => failure(message),
      };

  /// Maps the success value, preserving failures.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Success(transform(value)),
        Failure<T>(:final message) => Failure(message),
      };
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.message);
  final String message;
}
