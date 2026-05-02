import 'package:flutter_production_kit/flavors/white_label/white_label_client.dart';

/// Client A white-label branding configuration.
///
/// Replace placeholder values with actual client-provided assets before release.
final class ClientAConfig {
  ClientAConfig._();

  static const WhiteLabelBrandingConfig branding = WhiteLabelBrandingConfig(
    client: WhiteLabelClient.clientA,
    appName: 'Client A App',
    primaryColorHex: '#1A3C6E',
    secondaryColorHex: '#F4A300',
    logoAssetPath: 'assets/white_label/client_a/logo.png',
    supportEmail: 'support@clienta.example.com',
    privacyPolicyUrl: 'https://clienta.example.com/privacy',
    termsOfServiceUrl: 'https://clienta.example.com/terms',
  );
}
