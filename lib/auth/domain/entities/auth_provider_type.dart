library;

/// Auth provider types supported by the runtime.
///
/// Design rationale:
/// - Provider-agnostic architecture: the app never depends on a specific auth vendor.
/// - Each provider is a pluggable implementation of [AuthProvider].
/// - [composite] allows chaining multiple providers for fallback/recovery scenarios.
enum AuthProviderType {
  firebase,
  jwt,
  oauth,
  custom,
}
