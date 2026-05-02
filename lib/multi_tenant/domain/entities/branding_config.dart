/// Branding configuration — white-label branding for a tenant.
///
/// Design rationale:
/// - [tenantId] binds branding to a specific tenant.
/// - [appName] overrides the default app name.
/// - [logoUrl] is the tenant's logo.
/// - [primaryColor] and [secondaryColor] define the tenant's theme.
/// - [fontFamily] overrides the default font.
/// - [loginScreenConfig] customizes the login experience.
/// - [footerText] displays tenant-specific footer text.
/// - [supportEmail] and [supportPhone] for tenant-specific support.
/// - [metadata] carries safe diagnostic data.
///
/// Branding isolation:
/// - Branding is loaded per-tenant at startup.
/// - Cached branding is invalidated on tenant switch.
/// - Branding is never shared between tenants.
class BrandingConfig {
  const BrandingConfig({
    required this.tenantId,
    this.appName,
    this.logoUrl,
    this.faviconUrl,
    this.primaryColor,
    this.secondaryColor,
    this.backgroundColor,
    this.textColor,
    this.fontFamily,
    this.loginScreenConfig,
    this.footerText,
    this.supportEmail,
    this.supportPhone,
    this.termsUrl,
    this.privacyUrl,
    this.metadata = const {},
  });

  final String tenantId;
  final String? appName;
  final String? logoUrl;
  final String? faviconUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? backgroundColor;
  final String? textColor;
  final String? fontFamily;
  final LoginScreenConfig? loginScreenConfig;
  final String? footerText;
  final String? supportEmail;
  final String? supportPhone;
  final String? termsUrl;
  final String? privacyUrl;
  final Map<String, String> metadata;

  BrandingConfig mergeWithDefault(BrandingConfig defaults) {
    return BrandingConfig(
      tenantId: tenantId,
      appName: appName ?? defaults.appName,
      logoUrl: logoUrl ?? defaults.logoUrl,
      faviconUrl: faviconUrl ?? defaults.faviconUrl,
      primaryColor: primaryColor ?? defaults.primaryColor,
      secondaryColor: secondaryColor ?? defaults.secondaryColor,
      backgroundColor: backgroundColor ?? defaults.backgroundColor,
      textColor: textColor ?? defaults.textColor,
      fontFamily: fontFamily ?? defaults.fontFamily,
      loginScreenConfig: loginScreenConfig ?? defaults.loginScreenConfig,
      footerText: footerText ?? defaults.footerText,
      supportEmail: supportEmail ?? defaults.supportEmail,
      supportPhone: supportPhone ?? defaults.supportPhone,
      termsUrl: termsUrl ?? defaults.termsUrl,
      privacyUrl: privacyUrl ?? defaults.privacyUrl,
      metadata: {...defaults.metadata, ...metadata},
    );
  }
}

/// Login screen configuration for white-label customization.
class LoginScreenConfig {
  const LoginScreenConfig({
    this.backgroundImageUrl,
    this.welcomeMessage,
    this.showTenantLogo = true,
    this.showPoweredBy = false,
    this.poweredByText,
    this.customCss,
  });

  final String? backgroundImageUrl;
  final String? welcomeMessage;
  final bool showTenantLogo;
  final bool showPoweredBy;
  final String? poweredByText;
  final String? customCss;
}
