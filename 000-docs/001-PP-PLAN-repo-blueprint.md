# Repo Blueprint — wild-permission-analyzer

**Code:** PP-PLAN
**Status:** v1

---

## Mission

Provide a static audit library that catches permission model mistakes in `wild-capability-gate` YAML configs before they reach production. The analyzer reads `capabilities.yml` and `grants.yml`, runs six analyzers, and returns a structured `AuditReport` with findings sorted by severity.

## Problem Statement

The wild-capability-gate gem enforces permissions at runtime. That means misconfigured YAML — a grant referencing a non-existent capability, a wildcard covering a critical operation, a circular prerequisite chain — only surfaces when that code path is hit in production. This analyzer moves that detection left: run it in CI, in a pre-deploy hook, or as part of a config review workflow.

## Boundaries

### In scope

- Parse and validate `capabilities.yml` and `grants.yml` YAML structures
- Consistency analysis: every explicit grant references a real capability
- Risk analysis: wildcards on elevated capabilities; grants without expiry on elevated permissions
- Prerequisite analysis: missing, circular, and unsatisfiable prerequisite chains
- Coverage analysis: per-caller view of what is granted vs denied across all capabilities
- Orphan analysis: capabilities defined but never granted; grants for non-existent capabilities
- Shadow analysis: explicit grants made redundant by wildcard grants from the same caller
- JSON and Markdown export of audit results
- Configurable risk thresholds and prerequisite depth limit

### Out of scope

- Runtime enforcement (wild-capability-gate's job)
- Code-level static analysis (no AST parsing)
- Rails RBAC analysis
- Modifying any config files
- Network or subprocess operations

## Users

| User | How they use it |
|------|----------------|
| Platform engineer | Runs audit in CI pipeline before deploying new capability configs |
| Security reviewer | Exports Markdown report for pull request review annotation |
| Developer | Calls `coverage_for('my-service', ...)` locally to understand effective permissions |
| Ops team | Schedules periodic full audits against production config snapshots |

## Primary Use Cases

1. **Pre-deploy gate** — CI runs `WildPermissionAnalyzer.audit(...)`, fails if any `:error` or `:critical` findings exist
2. **Risk summary** — export JSON for dashboards showing wildcard coverage over time
3. **Caller onboarding** — developer runs coverage report for a new service caller to understand what they can/cannot do
4. **Config review** — security reviewer exports Markdown to annotate a PR that changes grants.yml

## Ecosystem Position

`wild-permission-analyzer` is a read-only companion to `wild-capability-gate`. It has no runtime dependency on the gate and can be run independently. It is intended for SDLC tooling — CI pipelines, pre-deploy checks, developer tooling — not for production hot paths.
