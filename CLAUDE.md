# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Identity

- **Repo:** wild-permission-analyzer
- **Ecosystem:** wild (see `../CLAUDE.md` for ecosystem-level rules)
- **Archetype:** C — SDLC Companion
- **Mission:** Statically audit capability-gate YAML configs for correctness, completeness, and risk before deployment
- **Namespace:** WildPermissionAnalyzer
- **Language:** Ruby 3.2+, pure library gem (no MCP, no ActiveRecord)
- **Status:** v1 complete — all 10 epics implemented, 217 tests passing, 0 RuboCop offenses

## What This Repo Does

- Parses `capabilities.yml` and `grants.yml` from wild-capability-gate configurations
- Runs six analyzers: consistency, risk, prerequisite, coverage, orphan, shadow
- Produces a structured `AuditReport` with sorted `Finding` objects and per-caller `CoverageReport` entries
- Exports audit results to JSON and Markdown
- Exposes a `WildPermissionAnalyzer.audit(...)` convenience method for one-call pipeline use

## What This Repo Does NOT Do

- Runtime permission enforcement (that is wild-capability-gate's job)
- Code-level static analysis
- Rails RBAC analysis
- Modify any config files
- Execute or spawn subprocesses

## Directory Layout

```
wild-permission-analyzer/
  000-docs/               canonical documentation
  lib/
    wild_permission_analyzer.rb               entry point, configure interface
    wild_permission_analyzer/
      version.rb                              VERSION = '0.1.0'
      errors.rb                              error hierarchy
      configuration.rb                       validated, freeze-on-configure config
      loaders/
        capabilities_loader.rb               parse capabilities.yml
        grants_loader.rb                     parse grants.yml
      models/
        capability.rb                        Capability definition
        grant.rb                             Grant definition
        finding.rb                           Analysis finding (type, severity, message, evidence)
        coverage_report.rb                   Per-caller coverage report
        audit_report.rb                      Complete audit report
      analyzers/
        wildcard_matcher.rb                  Wildcard pattern matching helper
        consistency_analyzer.rb              Cross-reference capabilities <-> grants
        risk_analyzer.rb                     Flag risky grant patterns
        prerequisite_analyzer.rb             Validate prerequisite chains
        coverage_analyzer.rb                 Per-caller coverage analysis
        orphan_analyzer.rb                   Find unused/unreferenced items
        shadow_analyzer.rb                   Find shadowed grants
      report/
        builder.rb                           Assemble AuditReport from all analyzers
      export/
        json_exporter.rb                     Export to JSON
        markdown_exporter.rb                 Export to Markdown
  spec/
    spec_helper.rb
    support/fixtures.rb                      Shared test fixtures and helpers
    wild_permission_analyzer/                unit specs (mirrors lib/ structure)
    integration/                             full_audit_spec, coverage_pipeline_spec
    adversarial/                             malformed_input_spec, edge_cases_spec
  planning/               pre-implementation notes
  000-docs/               canonical documentation
  Gemfile
  Rakefile
  wild-permission-analyzer.gemspec
```

## Build Commands

```bash
bundle install
bundle exec rspec                    # run all 217 specs
bundle exec rubocop                  # lint (must be 0 offenses)
bundle exec rake                     # default: runs rspec
```

## Config File Formats

**capabilities.yml:**
```yaml
capabilities:
  - name: "admin.jobs.retry"
    description: "Retry failed background jobs"
    risk_level: "medium"        # low | medium | high | critical
    prerequisites:
      - "admin.jobs.view"
    tags: ["admin", "jobs"]
```

**grants.yml:**
```yaml
grants:
  - caller_id: "ops-team"
    capabilities: ["admin.jobs.*"]
    context:
      environment: "production"
    expires_at: null            # or ISO date string "2026-06-01"
```

## Finding Types

| Type | Severity | Description |
|------|----------|-------------|
| `:missing_reference` | error | Grant references non-existent capability |
| `:wildcard_on_critical` | warning/error/critical | Wildcard covers a risky capability |
| `:no_expiry_elevated` | warning | Elevated grant has no expiry date |
| `:missing_prerequisite` | error | Capability requires an undefined prerequisite |
| `:circular_prerequisite` | critical | Prerequisite chain is circular |
| `:unsatisfiable_prerequisite` | error | Granted capability has unsatisfiable prerequisite |
| `:orphan_capability` | info | Capability defined but never granted |
| `:grant_references_missing_capability` | error | Orphan analyzer cross-check |
| `:shadowed_grant` | warning | Explicit grant is redundant due to wildcard |

## Safety Rules

1. Never add code that executes shell commands or spawns subprocesses.
2. Never add code that modifies capabilities.yml or grants.yml.
3. Validate all loaded YAML before processing; raise `LoadError` on structural failures.
4. Do not mutate configuration after `freeze!`; use `reset_configuration!` in tests only.
5. Do not add runtime gem dependencies; this gem has zero runtime dependencies beyond stdlib yaml.
6. Do not add network I/O, HTTP clients, or socket operations.

## Key Canonical Docs

| Doc | Purpose |
|-----|---------|
| 000-docs/001-PP-PLAN-repo-blueprint.md | Mission, boundaries, users, use cases |
| 000-docs/002-PP-PLAN-epic-build-plan.md | 10-epic build narrative |
| 000-docs/003-TQ-STND-safety-model.md | Safety rules and rationale |
| 000-docs/004-AT-ADEC-architecture-decisions.md | Why things are shaped the way they are |
| 000-docs/005-DR-REFF-configuration-reference.md | All config parameters with types and defaults |
| 000-docs/006-OD-GUID-operator-workflow-guide.md | Usage flow, config examples, finding interpretation |

## Before Working Here

1. Read `../CLAUDE.md` for ecosystem-level rules and work sequence standards.
2. Read `000-docs/001-PP-PLAN-repo-blueprint.md` for mission and boundaries.
3. Read `000-docs/004-AT-ADEC-architecture-decisions.md` before changing structural decisions.
4. Run `bundle exec rspec` and confirm 217 examples, 0 failures before making changes.
5. Run `bundle exec rubocop` and confirm 0 offenses before committing.
