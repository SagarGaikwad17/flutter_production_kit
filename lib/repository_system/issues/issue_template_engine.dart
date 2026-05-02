/// Issue template engine — generates and manages issue templates for GitHub.
///
/// Design rationale:
/// - Issue templates reduce noise and improve issue quality.
/// - Different templates for bugs, features, and questions.
/// - Templates guide reporters to provide necessary information.
/// - Reduces maintainer triage time.
///
/// Template types:
/// 1. Bug report — reproduction steps, environment, expected vs actual.
/// 2. Feature request — use case, proposed solution, alternatives.
/// 3. Documentation — missing or incorrect documentation.
/// 4. Question — usage question, architecture question.
/// 5. Maintenance — dependency updates, refactoring, cleanup.
class IssueTemplateEngine {
  const IssueTemplateEngine({
    this.templates = const {
      'bug': _bugTemplate,
      'feature': _featureTemplate,
      'documentation': _documentationTemplate,
      'question': _questionTemplate,
      'maintenance': _maintenanceTemplate,
    },
  });

  final Map<String, String> templates;

  /// Generate an issue template as a markdown string.
  String? generateTemplate(String type) {
    return templates[type];
  }

  /// Validate an issue against its template.
  bool validateIssue({
    required String type,
    required String content,
  }) {
    final template = templates[type];
    if (template == null) return false;

    // Check for required sections
    final requiredSections = _extractRequiredSections(template);
    for (final section in requiredSections) {
      if (!content.toLowerCase().contains(section.toLowerCase())) {
        return false;
      }
    }

    return true;
  }

  /// Get all available template types.
  List<String> getAvailableTypes() {
    return templates.keys.toList();
  }

  List<String> _extractRequiredSections(String template) {
    final sections = <String>[];
    final regex = RegExp(r'###\s+(.+?)\s*\n');
    for (final match in regex.allMatches(template)) {
      sections.add(match.group(1)!);
    }
    return sections;
  }

  static const _bugTemplate = '''
### Description
A clear and concise description of the bug.

### Steps to Reproduce
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

### Expected Behavior
What you expected to happen.

### Actual Behavior
What actually happened.

### Environment
- OS: [e.g. iOS, Android, Web]
- Flutter version: [e.g. 3.19.0]
- Package version: [e.g. 1.0.0]
- Device: [e.g. iPhone 14, Pixel 7]

### Additional Context
Add any other context about the problem here.

### Screenshots
If applicable, add screenshots to help explain your problem.
''';

  static const _featureTemplate = '''
### Is your feature request related to a problem?
A clear and concise description of what the problem is. Ex. I'm always frustrated when [...]

### Describe the solution you'd like
A clear and concise description of what you want to happen.

### Describe alternatives you've considered
A clear and concise description of any alternative solutions or features you've considered.

### Additional Context
Add any other context or screenshots about the feature request here.

### Use Case
Describe the specific use case this feature would enable.
''';

  static const _documentationTemplate = '''
### Documentation Issue
Describe what is missing, incorrect, or unclear in the documentation.

### Location
Where is the documentation issue? (URL, file path, section)

### Suggested Improvement
What should the documentation say instead?

### Additional Context
Add any other context about the documentation issue here.
''';

  static const _questionTemplate = '''
### Question
What would you like to know?

### Context
Provide any relevant context about your question.

### What I've Tried
Describe what you've already tried to find the answer.

### Additional Information
- Package version:
- Flutter version:
- Platform:
''';

  static const _maintenanceTemplate = '''
### Maintenance Type
What type of maintenance is needed? (dependency update, refactoring, cleanup, etc.)

### Current State
Describe the current state of the code/dependencies.

### Proposed Changes
What changes are you proposing?

### Impact
What is the impact of these changes? (breaking, non-breaking, performance, etc.)

### Additional Context
Add any other context about the maintenance task here.
''';
}
