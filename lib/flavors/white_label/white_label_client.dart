/// White-label client registry.
///
/// Add new clients here as the business grows.
/// Each client corresponds to a [AppFlavor.whiteLabelClient*] flavor and
/// a matching [BaseEnv] implementation.
library;

enum WhiteLabelClient {
  clientA,
  clientB;

  String get clientId => switch (this) {
        WhiteLabelClient.clientA => 'client_a',
        WhiteLabelClient.clientB => 'client_b',
      };

  String get displayName => switch (this) {
        WhiteLabelClient.clientA => 'Enterprise Client A',
        WhiteLabelClient.clientB => 'Enterprise Client B',
      };
}

/// Branding configuration for a white-label client.
///
/// All fields are required and strongly typed.
/// No nullable String? to allow partial branding — this creates mismatches.
class WhiteLabelBrandingConfig {
  const WhiteLabelBrandingConfig({
    required this.client,
    required this.appName,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.logoAssetPath,
    required this.supportEmail,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
  });

  final WhiteLabelClient client;
  final String appName;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String logoAssetPath;
  final String supportEmail;
  final String privacyPolicyUrl;
  final String termsOfServiceUrl;

  @override
  String toString() =>
      'WhiteLabelBrandingConfig(client: ${client.clientId}, app: $appName)';
}
