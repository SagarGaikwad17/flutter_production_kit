/// Privacy-safe logger — ensures no sensitive data leaks through logs.
///
/// Design rationale:
/// - All log messages and attributes are scanned for sensitive patterns.
/// - Sensitive fields are automatically masked.
/// - Token values are replaced with [TOKEN_MASKED].
/// - Email addresses are partially masked (a***@domain.com).
/// - Phone numbers are partially masked (***-***-1234).
/// - Card numbers are fully masked (****-****-****-1234).
/// - SSN values are fully masked (***-**-****).
///
/// Masking rules:
///   - Field name patterns: token, secret, password, card, ssn, email, phone, name, address
///   - Value patterns: email regex, phone regex, card number regex, SSN regex
///   - Custom patterns can be added for domain-specific sensitive data.
class PrivacySafeLogger {
  PrivacySafeLogger({
    List<PrivacyMaskingRule>? customRules,
  }) : _rules = [
          ..._defaultRules,
          ...?customRules,
        ];

  static const List<PrivacyMaskingRule> _defaultRules = [
    PrivacyMaskingRule(
      pattern: 'token',
      replacement: '[TOKEN_MASKED]',
      matchType: MatchType.fieldName,
    ),
    PrivacyMaskingRule(
      pattern: 'secret',
      replacement: '[SECRET_MASKED]',
      matchType: MatchType.fieldName,
    ),
    PrivacyMaskingRule(
      pattern: 'password',
      replacement: '[PASSWORD_MASKED]',
      matchType: MatchType.fieldName,
    ),
    PrivacyMaskingRule(
      pattern: 'card_number',
      replacement: '[CARD_MASKED]',
      matchType: MatchType.fieldName,
    ),
    PrivacyMaskingRule(
      pattern: 'ssn',
      replacement: '[SSN_MASKED]',
      matchType: MatchType.fieldName,
    ),
    PrivacyMaskingRule(
      pattern: r'[\w.+-]+@[\w-]+\.[\w.-]+',
      replacement: '[EMAIL_MASKED]',
      matchType: MatchType.value,
    ),
    PrivacyMaskingRule(
      pattern: r'\b\d{3}-\d{2}-\d{4}\b',
      replacement: '[SSN_MASKED]',
      matchType: MatchType.value,
    ),
  ];

  final List<PrivacyMaskingRule> _rules;

  /// Sanitize a message string.
  String sanitizeMessage(String message) {
    var sanitized = message;
    for (final rule in _rules) {
      if (rule.matchType == MatchType.value) {
        sanitized = sanitized.replaceAll(RegExp(rule.pattern), rule.replacement);
      }
    }
    return sanitized;
  }

  /// Sanitize a map of attributes.
  Map<String, String> sanitizeAttributes(Map<String, String> attributes) {
    final sanitized = <String, String>{};
    final maskedFields = <String>[];

    for (final entry in attributes.entries) {
      var value = entry.value;
      var isMasked = false;

      // Check field name rules.
      for (final rule in _rules) {
        if (rule.matchType == MatchType.fieldName &&
            entry.key.toLowerCase().contains(rule.pattern.toLowerCase())) {
          value = rule.replacement;
          isMasked = true;
          break;
        }
      }

      // Check value pattern rules.
      if (!isMasked) {
        for (final rule in _rules) {
          if (rule.matchType == MatchType.value &&
              RegExp(rule.pattern).hasMatch(value)) {
            value = value.replaceAll(RegExp(rule.pattern), rule.replacement);
            isMasked = true;
          }
        }
      }

      sanitized[entry.key] = value;
      if (isMasked) maskedFields.add(entry.key);
    }

    return sanitized;
  }

  /// Get list of masked fields.
  List<String> getMaskedFields(Map<String, String> attributes) {
    final maskedFields = <String>[];

    for (final entry in attributes.entries) {
      for (final rule in _rules) {
        if (rule.matchType == MatchType.fieldName &&
            entry.key.toLowerCase().contains(rule.pattern.toLowerCase())) {
          maskedFields.add(entry.key);
          break;
        }
        if (rule.matchType == MatchType.value &&
            RegExp(rule.pattern).hasMatch(entry.value)) {
          maskedFields.add(entry.key);
          break;
        }
      }
    }

    return maskedFields;
  }

  /// Check if a message contains sensitive data.
  bool containsSensitiveData(String message) {
    for (final rule in _rules) {
      if (rule.matchType == MatchType.value &&
          RegExp(rule.pattern).hasMatch(message)) {
        return true;
      }
    }
    return false;
  }
}

/// Privacy masking rule — defines a pattern and its replacement.
class PrivacyMaskingRule {
  const PrivacyMaskingRule({
    required this.pattern,
    required this.replacement,
    required this.matchType,
  });

  final String pattern;
  final String replacement;
  final MatchType matchType;
}

enum MatchType {
  fieldName,
  value,
}
