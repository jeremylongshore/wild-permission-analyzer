# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-03-20

Initial release. All 10 epics implemented.

### Added

**Epic 1 — Project scaffold and gem foundation**
- Gemspec with `wild-permission-analyzer` name, version 0.1.0, Ruby >= 3.2 constraint, single stdlib dependency (yaml)
- Gemfile with rspec, rubocop, rubocop-rspec development dependencies
- Rakefile with default rspec task
- Top-level `WildPermissionAnalyzer` module with `configure`, `configuration`, `reset_configuration!`, and `audit` class methods
- Error class hierarchy: `Error`, `ConfigurationError`, `LoadError`, `AnalysisError`, `ExportError`
- RSpec spec_helper with `PermissionFixtures` mixin and `reset_configuration!` before hook for test isolation

**Epic 2 — Configuration system**
- `Configuration` class with five validated parameters: `capabilities_path`, `grants_path`, `risk_levels`, `wildcard_risk_threshold`, `max_prerequisite_depth`
- `freeze!` method that deep-freezes `risk_levels` and then freezes the object
- `DEFAULT_RISK_LEVELS` constant: `{ 'low' => 1, 'medium' => 2, 'high' => 3, 'critical' => 4 }`
- Validated setters with descriptive `ConfigurationError` messages on invalid input

**Epic 3 — Core domain models**
- `Models::Capability` with `name`, `description`, `risk_level`, `prerequisites`, `tags` and frozen arrays, equality by name
- `Models::Grant` with `caller_id`, `capabilities`, `context`, `expires_at`, `wildcard_capabilities` helper, `expired?` predicate
- `Models::Finding` with `type` (symbol), `severity` (:info/:warning/:error/:critical), `message`, `evidence` (frozen hash), and `Comparable` ordering by severity
- `Models::CoverageReport` with `caller_id`, `granted_capabilities`, `denied_capabilities`, `grant_chain`, `coverage_ratio`
- `Models::AuditReport` with sorted findings, coverage reports, `summary` stats hash, and `findings_by_severity` helper

**Epic 4 — YAML loaders**
- `Loaders::CapabilitiesLoader` parsing `capabilities.yml` via `YAML.safe_load`; raises `LoadError` on missing file, invalid YAML, or wrong structure; skips malformed individual entries
- `Loaders::GrantsLoader` parsing `grants.yml`; same error handling; filters non-string capability values via `grep(String)`

**Epic 5 — Wildcard matcher and consistency analyzer**
- `Analyzers::WildcardMatcher` module with `matches?` (pattern vs name) and `resolve_patterns` (expand patterns against a capability name list); uses `Regexp.escape` so dots are literal
- `Analyzers::ConsistencyAnalyzer` flagging explicit grant references to non-existent capabilities as `:missing_reference` / `:error`

**Epic 6 — Risk analyzer**
- `Analyzers::RiskAnalyzer` flagging wildcard patterns that cover capabilities at or above `wildcard_risk_threshold` as `:wildcard_on_critical`; severity mapped to the capability's own risk level
- Flags grants with no expiry date covering elevated capabilities as `:no_expiry_elevated` / `:warning`
- Respects `wildcard_risk_threshold` configuration parameter

**Epic 7 — Prerequisite analyzer**
- `Analyzers::PrerequisiteAnalyzer` detecting missing prerequisites (`:missing_prerequisite` / `:error`), circular chains (`:circular_prerequisite` / `:critical`), and unsatisfiable prerequisites in granted capabilities (`:unsatisfiable_prerequisite` / `:error`)
- Circular detection uses visited-path recursion bounded by `max_prerequisite_depth`

**Epic 8 — Coverage and orphan analyzers**
- `Analyzers::CoverageAnalyzer` producing one `CoverageReport` per caller; resolves wildcards to concrete capability names; populates `grant_chain` mapping each capability to the grants that provide it
- `coverage_for(caller_id, ...)` convenience method for single-caller queries
- `Analyzers::OrphanAnalyzer` detecting capabilities never matched by any grant pattern (`:orphan_capability` / `:info`) and grants referencing non-existent capabilities (`:grant_references_missing_capability` / `:error`)

**Epic 9 — Shadow analyzer and report builder**
- `Analyzers::ShadowAnalyzer` detecting explicit grants made redundant by wildcard grants from the same caller (`:shadowed_grant` / `:warning`)
- `Report::Builder` orchestrating all six analyzers and assembling a complete `AuditReport`
- `WildPermissionAnalyzer.audit(capabilities_path:, grants_path:)` one-call convenience method

**Epic 10 — Export and adversarial testing**
- `Export::JsonExporter` producing a JSON document with metadata, summary, findings, and coverage reports; raises `ExportError` on non-`AuditReport` input
- `Export::MarkdownExporter` producing a Markdown report with summary table, findings table, and coverage-by-caller table; escapes pipe and backtick characters
- `spec/adversarial/malformed_input_spec.rb` covering nil, empty, invalid YAML, wrong-structure, and non-string entries for both loaders
- `spec/adversarial/edge_cases_spec.rb` covering special characters, unicode, very long names, large-scale performance (500 caps / 200 grants in < 5s), wildcard edge cases, circular prerequisites, configuration freeze, shadow analysis, and markdown safety
- `spec/integration/full_audit_spec.rb` covering end-to-end pipeline with YAML file loading, all finding types, both exporters, and error paths
- `spec/integration/coverage_pipeline_spec.rb` covering multi-caller coverage analysis with wildcards and explicit grants
- 217 examples, 0 failures; 49 files inspected, 0 RuboCop offenses

---

[0.1.0]: https://github.com/jeremylongshore/wild-permission-analyzer/releases/tag/v0.1.0
