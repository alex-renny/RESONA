/// A user-facing error with a friendly [message] plus optional
/// [technicalDetails] for internal logging. Services throw this instead of
/// letting raw platform exceptions reach the UI (spec section 38: never
/// display a raw exception as the primary UI, but keep the detail around for
/// debugging).
class AppException implements Exception {
  final String message;
  final String? technicalDetails;

  const AppException(this.message, {this.technicalDetails});

  @override
  String toString() => technicalDetails == null ? message : '$message ($technicalDetails)';
}
