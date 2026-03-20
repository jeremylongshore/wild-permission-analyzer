# Epic Build Plan — wild-permission-analyzer

**Code:** PP-PLAN
**Status:** v1

---

## Epic 1 — Project scaffold and gem foundation

Set up the repo with gemspec, Gemfile, Rakefile, .rspec, .rubocop.yml, and the top-level module with `configure`, `configuration`, `reset_configuration!`, and `audit` methods. Define the error hierarchy.

**Acceptance:** `bundle install` succeeds; `bundle exec rake` runs (no specs yet).

---

## Epic 2 — Configuration system

Implement `Configuration` with five validated parameters. Support `freeze!` for immutability after the configure block. Raise `ConfigurationError` with descriptive messages on invalid input.

**Acceptance:** Configuration specs pass; `freeze!` enforced.

---

## Epic 3 — Core domain models

Build `Capability`, `Grant`, `Finding`, `CoverageReport`, and `AuditReport`. Finding has severity ordering. AuditReport sorts findings by severity and exposes a `summary` hash.

**Acceptance:** All model specs pass.

---

## Epic 4 — YAML loaders

`CapabilitiesLoader` and `GrantsLoader` parse YAML files via `YAML.safe_load`. Both raise `LoadError` on missing file, invalid YAML, or wrong top-level structure. Both skip (not raise on) malformed individual entries.

**Acceptance:** Loader specs pass including error cases.

---

## Epic 5 — Wildcard matcher and consistency analyzer

`WildcardMatcher` module with `matches?` and `resolve_patterns`. Uses `Regexp.escape` so dots are literals. `ConsistencyAnalyzer` flags explicit grant references to non-existent capabilities.

**Acceptance:** Wildcard and consistency specs pass.

---

## Epic 6 — Risk analyzer

`RiskAnalyzer` flags wildcard grants covering capabilities at or above `wildcard_risk_threshold`. Severity derived from capability's own risk level. Also flags grants with no expiry date covering elevated capabilities.

**Acceptance:** Risk analyzer specs pass including threshold configuration.

---

## Epic 7 — Prerequisite analyzer

`PrerequisiteAnalyzer` detects missing prerequisites, circular chains (bounded by `max_prerequisite_depth`), and unsatisfiable prerequisites in granted capabilities.

**Acceptance:** Prerequisite specs pass including 3-node circular chain.

---

## Epic 8 — Coverage and orphan analyzers

`CoverageAnalyzer` produces one `CoverageReport` per caller resolving wildcards to concrete names. `OrphanAnalyzer` finds capabilities never covered by any grant pattern and grants referencing missing capabilities.

**Acceptance:** Coverage and orphan specs pass.

---

## Epic 9 — Shadow analyzer and report builder

`ShadowAnalyzer` finds explicit grants made redundant by wildcards from the same caller. `Report::Builder` orchestrates all six analyzers into a single `AuditReport`. `WildPermissionAnalyzer.audit(...)` wires loaders and builder together.

**Acceptance:** Shadow specs pass; builder integration tests pass; end-to-end audit call works.

---

## Epic 10 — Export and adversarial testing

`Export::JsonExporter` and `Export::MarkdownExporter`. Full adversarial and integration specs: malformed YAML, nil inputs, special characters, large-scale performance, wildcard edge cases, circular chains, markdown table safety.

**Acceptance:** 200+ specs, 0 failures, 0 RuboCop offenses.
