import 'package:flutter_production_kit/flavors/white_label/white_label_client.dart';

/// Client B white-label branding configuration.
///
/// Replace placeholder values with actual client-provided assets before release.
final class ClientBConfig {
  ClientBConfig._();

  static const WhiteLabelBrandingConfig branding = WhiteLabelBrandingConfig(
    client: WhiteLabelClient.clientB,
    appName: 'Client B App',
    primaryColorHex: '#2D6A4F',
    secondaryColorHex: '#FFD166',
    logoAssetPath: 'assets/white_label/client_b/logo.png',
    supportEmail: 'support@clientb.example.com',
    privacyPolicyUrl: 'https://clientb.example.com/privacy',
    termsOfServiceUrl: 'https://clientb.example.com/terms',
  );
}
