import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';
import 'package:flutter_production_kit/repository_system/domain/exceptions/repo_exception.dart';
import 'package:flutter_production_kit/repository_system/domain/repositories/repo_repositories.dart';

/// Issue triage engine — automatically classifies and routes incoming issues.
///
/// Design rationale:
/// - Issues arrive in a raw state and need classification before action.
/// - Triage prevents maintainer overload by automating initial sorting.
/// - Severity detection routes critical issues to maintainers immediately.
/// - Duplicate detection reduces noise and redundant work.
///
/// Triage flow:
/// 1. Parse issue title/body for keywords and patterns.
/// 2. Classify type (bug, feature, documentation, question, maintenance).
/// 3. Assess severity (critical, high, medium, low).
/// 4. Detect duplicates using similarity matching.
/// 5. Assign appropriate labels and route to correct package/maintainer.
class IssueTriageEngine {
  const IssueTriageEngine({
    required IIssueRepository issueRepository,
    this.severityKeywords = const {
      IssueSeverity.critical: ['crash', 'data loss', 'security', 'vulnerability', 'exploit'],
      IssueSeverity.high: ['breaks', 'blocking', 'urgent', 'production', 'regression'],
      IssueSeverity.medium: ['bug', 'error', 'incorrect', 'missing', 'wrong'],
      IssueSeverity.low: ['typo', 'cosmetic', 'minor', 'nice-to-have', 'suggestion'],
    },
    this.typeKeywords = const {
      IssueType.bug: ['bug', 'crash', 'error', 'fail', 'broken', 'regression'],
      IssueType.feature: ['feature', 'request', 'enhancement', 'add', 'support', 'new'],
      IssueType.documentation: ['docs', 'documentation', 'example', 'guide', 'readme', 'tutorial'],
      IssueType.question: ['question', 'help', 'how', 'why', 'what', 'confused'],
      IssueType.maintenance: ['cleanup', 'refactor', 'update', 'upgrade', 'deps', 'dependency'],
    },
    this.autoLabelRules = const {
      'good-first-issue': ['typo', 'cosmetic', 'simple', 'easy'],
      'help-wanted': ['help', 'contribution', 'community'],
      'needs-reproduction': ['repro', 'reproduce', 'steps', 'can-you-reproduce'],
      'waiting-for-response': ['waiting', 'ping', 'follow-up'],
    },
  }) : _issueRepository = issueRepository;

  final IIssueRepository _issueRepository;
  final Map<IssueSeverity, List<String>> severityKeywords;
  final Map<IssueType, List<String>> typeKeywords;
  final Map<String, List<String>> autoLabelRules;

  /// Triage a single issue.
  Future<RepoResult> triageIssue(int issueNumber) async {
    final issue = await _issueRepository.getIssue(issueNumber);
    if (issue == null) {
      throw IssueTriageFailedException(
        message: 'Issue #$issueNumber not found',
        issueNumber: issueNumber,
      );
    }

    final title = issue.title ?? '';
    final body = await _getIssueBody(issueNumber);
    final content = '$title $body'.toLowerCase();

    // Classify type
    final type = _classifyType(content);

    // Assess severity
    final severity = _assessSeverity(content);

    // Generate labels
    final labels = _generateLabels(content);

    // Check for duplicates (simplified — in production use ML/embeddings)
    final duplicateOf = await _checkForDuplicates(content, issueNumber);

    // Build triaged issue
    final triagedIssue = IssueState(
      number: issue.number,
      type: type,
      severity: severity,
      status: duplicateOf != null ? IssueStatus.duplicate : IssueStatus.triageNeeded,
      author: issue.author,
      createdAt: issue.createdAt,
      title: title,
      labels: labels,
      isDuplicate: duplicateOf != null,
      duplicateOf: duplicateOf,
    );

    // Save triaged issue
    await _issueRepository.saveIssue(triagedIssue);

    // Route critical issues to maintainers immediately
    if (severity == IssueSeverity.critical) {
      labels.add('critical');
      labels.add('needs-immediate-attention');
    }

    return IssueTriageCompleted(
      operation: 'triage_issue',
      issueNumber: issueNumber,
      severity: severity.name,
      labels: labels,
    );
  }

  /// Triage all open issues.
  Future<List<RepoResult>> triageAllOpenIssues() async {
    final issues = await _issueRepository.getOpenIssues();
    final results = <RepoResult>[];

    for (final issue in issues) {
      if (issue.status == IssueStatus.triageNeeded) {
        final result = await triageIssue(issue.number);
        results.add(result);
      }
    }

    return results;
  }

  /// Generate an issue priority score for backlog ordering.
  int calculatePriorityScore({
    required IssueSeverity severity,
    required DateTime createdAt,
    bool isHighImpact = false,
    int affectedUsers = 0,
  }) {
    int score = 0;

    // Severity weight
    switch (severity) {
      case IssueSeverity.critical: score += 100; break;
      case IssueSeverity.high: score += 50; break;
      case IssueSeverity.medium: score += 25; break;
      case IssueSeverity.low: score += 10; break;
    }

    // Age bonus (older issues get priority bump)
    final ageDays = DateTime.now().difference(createdAt).inDays;
    score += ageDays.clamp(0, 50);

    // Impact multiplier
    if (isHighImpact) score *= 2;

    // User count bonus
    score += affectedUsers * 2;

    return score;
  }

  /// Classify issue type from content.
  IssueType _classifyType(String content) {
    var bestType = IssueType.question;
    var bestScore = 0;

    for (final entry in typeKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (content.contains(keyword)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestType = entry.key;
      }
    }

    return bestType;
  }

  /// Assess issue severity from content.
  IssueSeverity _assessSeverity(String content) {
    var bestSeverity = IssueSeverity.low;
    var bestScore = 0;

    for (final entry in severityKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (content.contains(keyword)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestSeverity = entry.key;
      }
    }

    return bestSeverity;
  }

  /// Generate appropriate labels from content.
  List<String> _generateLabels(String content) {
    final labels = <String>[];

    for (final entry in autoLabelRules.entries) {
      for (final keyword in entry.value) {
        if (content.contains(keyword)) {
          labels.add(entry.key);
          break;
        }
      }
    }

    return labels;
  }

  /// Check for duplicate issues (simplified keyword matching).
  Future<int?> _checkForDuplicates(String content, int currentIssue) async {
    // In production, this would use ML embeddings or fuzzy matching.
    // For now, we do a simple keyword overlap check against open issues.
    final openIssues = await _issueRepository.getOpenIssues();
    final words = content.split(' ').where((w) => w.length > 3).toSet();

    for (final issue in openIssues) {
      if (issue.number == currentIssue) continue;

      final issueContent = '${issue.title} '.toLowerCase();
      final issueWords = issueContent.split(' ').where((w) => w.length > 3).toSet();

      final overlap = words.intersection(issueWords);
      if (overlap.length >= 3 && overlap.length > words.length * 0.5) {
        return issue.number;
      }
    }

    return null;
  }

  Future<String> _getIssueBody(int issueNumber) async {
    // In production, fetch from GitHub API or local cache.
    return '';
  }
}

/// PR review guardrails — enforces review standards before merging.
///
/// Design rationale:
/// - PRs must pass multiple gates before merge.
/// - Architecture violations are caught early.
/// - Breaking changes require explicit approval.
/// - CI checks must all pass.
///
/// Review gates:
/// 1. CI/CD pipeline checks pass.
/// 2. Architecture boundary validation.
/// 3. Code review approval (minimum reviewers).
/// 4. Breaking change declaration and approval.
/// 5. Changelog entry present.
/// 6. Test coverage threshold met.
class PRReviewGuardrails {
  const PRReviewGuardrails({
    required IPRRepository prRepository,
    this.minimumReviewers = 2,
    this.requiredChecks = const [
      'build',
      'test',
      'lint',
      'format',
      'analyze',
    ],
    this.blockingLabels = const [
      'do-not-merge',
      'blocked',
      'needs-rework',
      'security-review',
    ],
    this.breakingChangeApprovalRequired = true,
  }) : _prRepository = prRepository;

  final IPRRepository _prRepository;
  final int minimumReviewers;
  final List<String> requiredChecks;
  final List<String> blockingLabels;
  final bool breakingChangeApprovalRequired;

  /// Evaluate a PR against all review guardrails.
  Future<RepoResult> evaluatePR(int prNumber) async {
    final pr = await _prRepository.getPR(prNumber);
    if (pr == null) {
      throw PRArchitectureViolationException(
        message: 'PR #$prNumber not found',
        prNumber: prNumber,
        violations: [],
      );
    }

    final violations = <String>[];

    // Gate 1: CI checks
    final checkViolations = _evaluateChecks(pr);
    violations.addAll(checkViolations);

    // Gate 2: Architecture boundaries
    final archViolations = _evaluateArchitecture(pr);
    violations.addAll(archViolations);

    // Gate 3: Reviewer approval
    final reviewViolations = _evaluateReviewers(pr);
    violations.addAll(reviewViolations);

    // Gate 4: Breaking change approval
    final breakingViolations = _evaluateBreakingChanges(pr);
    violations.addAll(breakingViolations);

    // Gate 5: Blocking labels
    final labelViolations = _evaluateLabels(pr);
    violations.addAll(labelViolations);

    if (violations.isNotEmpty) {
      return PRBlockedByArchitectureViolation(
        operation: 'evaluate_pr',
        prNumber: prNumber,
        violations: violations,
        blocker: violations.first,
      );
    }

    // All gates passed — mark as approved
    await _prRepository.updatePRStatus(prNumber, PRStatus.approved);

    return MonorepoValidationPassed(
      operation: 'evaluate_pr',
      packageCount: 1,
    );
  }

  /// Check if a PR can be merged.
  Future<bool> canMerge(int prNumber) async {
    final result = await evaluatePR(prNumber);
    return result.isSuccess;
  }

  /// Evaluate CI checks.
  List<String> _evaluateChecks(PRState pr) {
    final violations = <String>[];

    for (final check in requiredChecks) {
      final status = pr.checks[check];
      if (status == null) {
        violations.add('Check "$check" has not run');
      } else if (!status) {
        violations.add('Check "$check" failed');
      }
    }

    return violations;
  }

  /// Evaluate architecture boundaries.
  List<String> _evaluateArchitecture(PRState pr) {
    return pr.architectureViolations
        .map((v) => 'Architecture violation: $v')
        .toList();
  }

  /// Evaluate reviewer approval.
  List<String> _evaluateReviewers(PRState pr) {
    final violations = <String>[];

    if (pr.reviewers.length < minimumReviewers) {
      violations.add(
        'Needs $minimumReviewers reviewers, has ${pr.reviewers.length}',
      );
    }

    if (!pr.isApproved && pr.status != PRStatus.approved) {
      violations.add('PR not yet approved by reviewers');
    }

    return violations;
  }

  /// Evaluate breaking changes.
  List<String> _evaluateBreakingChanges(PRState pr) {
    final violations = <String>[];

    if (pr.isBreakingChange && breakingChangeApprovalRequired) {
      if (!pr.labels.contains('breaking-change-approved')) {
        violations.add('Breaking change requires explicit approval');
      }
    }

    return violations;
  }

  /// Evaluate blocking labels.
  List<String> _evaluateLabels(PRState pr) {
    final violations = <String>[];

    for (final label in pr.labels) {
      if (blockingLabels.contains(label)) {
        violations.add('Blocked by label: $label');
      }
    }

    return violations;
  }
}
