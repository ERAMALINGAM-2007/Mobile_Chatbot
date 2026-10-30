class AppError implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppError(this.message, {this.code, this.details});

  @override
  String toString() => 'AppError: $message ${code != null ? '($code)' : ''}';
}

class IngestionError extends AppError {
  const IngestionError(super.message, {super.code, super.details});
}

class InferenceError extends AppError {
  const InferenceError(super.message, {super.code, super.details});
}

class DatabaseError extends AppError {
  const DatabaseError(super.message, {super.code, super.details});
}

class ModelNotFoundError extends AppError {
  const ModelNotFoundError(super.message, {super.code, super.details});
}
