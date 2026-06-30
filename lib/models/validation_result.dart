class ValidationResult {
  final bool isValid;
  final Map<String, String> errors; // field name -> error message
  final String? generalError;

  const ValidationResult({
    this.isValid = true,
    this.errors = const {},
    this.generalError,
  });

  String? get firstError => errors.values.isNotEmpty ? errors.values.first : generalError;
  bool hasError(String field) => errors.containsKey(field);
  String? errorFor(String field) => errors[field];

  const ValidationResult.valid() : isValid = true, errors = {}, generalError = null;

  factory ValidationResult.invalid(Map<String, String> errors, {String? generalError}) {
    return ValidationResult(isValid: false, errors: errors, generalError: generalError);
  }

  factory ValidationResult.error(String message) {
    return ValidationResult(isValid: false, errors: {}, generalError: message);
  }

  static ValidationResult merge(List<ValidationResult> results) {
    final allErrors = <String, String>{};
    String? firstGeneral;
    for (final r in results) {
      if (!r.isValid) {
        allErrors.addAll(r.errors);
        firstGeneral ??= r.generalError;
      }
    }
    if (allErrors.isEmpty && firstGeneral == null) return const ValidationResult.valid();
    return ValidationResult(isValid: false, errors: allErrors, generalError: firstGeneral);
  }
}
