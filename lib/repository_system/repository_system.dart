/// Repository System Module — Phase 14
///
/// GitHub Foundation + Repository Architecture + Open-Source Launch System.
///
/// Provides enterprise-grade monorepo strategy, CI/CD governance, trust-first
/// project presentation, and sustainable maintainer workflows.
library;

// Domain
export 'domain/entities/repo_result.dart';
export 'domain/exceptions/repo_exception.dart';
export 'domain/repositories/repo_repositories.dart';

// Monorepo
export 'monorepo/repo_structure_manager.dart';

// Issues
export 'issues/issue_triage_engine.dart';
export 'issues/issue_template_engine.dart';

// CI/CD
export 'github_actions/ci_validation_engine.dart';

// Releases
export 'releases/release_governance_engine.dart';

// Governance
export 'governance/maintainer_policy.dart';

// Contributors
export 'contributors/contributor_onboarding_manager.dart';

// Roadmap
export 'roadmap/public_roadmap_engine.dart';

// Trust
export 'trust/readme_trust_framework.dart';

// Maintenance
export 'maintenance/maintainer_sustainability_engine.dart';
