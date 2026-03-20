# Safety Model — wild-permission-analyzer

**Code:** TQ-STND
**Status:** v1

---

## Archetype C: SDLC Companion

This gem is an Archetype C tool — a companion to a runtime system, used during the software development lifecycle (CI, pre-deploy, code review). It never runs in the hot path and never touches anything it is analyzing.

---

## Safety Rules

### Rule 1 — Read-only operation

The analyzer NEVER modifies any file. It reads `capabilities.yml` and `grants.yml` once, analyzes in memory, and returns structured output. No write operations are permitted in any analyzer or exporter.

**Rationale:** An audit tool that modifies configs creates uncertainty about whether the config being analyzed matches the config being enforced.

### Rule 2 — No subprocess execution

No code in this gem may invoke shell commands, spawn subprocesses, or use `system`, `exec`, `Kernel#`, backticks, or `Open3`. This includes the YAML loader — even though path-like strings may appear in capability names, they are treated as opaque string identifiers.

**Rationale:** An audit tool that executes arbitrary strings from config files would itself be a security risk.

### Rule 3 — No network I/O

No code may open network connections, make HTTP requests, or use socket operations. The analyzer is a pure in-memory transform.

**Rationale:** Audit tools must be runnable in air-gapped CI environments.

### Rule 4 — Raise on structural failure, skip on entry failure

Loaders raise `LoadError` when the file is missing, the YAML is syntactically invalid, or the top-level structure is wrong (e.g., missing `capabilities` key). They skip (return nil, which is filtered out) when an individual entry is malformed. Analyzers do not raise on bad data — they produce findings.

**Rationale:** A missing file or wrong-format file is always a user error and should surface loudly. A single malformed entry in a valid file should not prevent the rest from being audited.

### Rule 5 — No configuration mutation after freeze

`Configuration#freeze!` is called at the end of `WildPermissionAnalyzer.configure`. After that, any mutation attempt raises `FrozenError`. Tests must call `reset_configuration!` in a before hook.

**Rationale:** Analyzer instances capture the configuration at construction time. Mutable configuration during a run would produce inconsistent results.

### Rule 6 — Zero runtime dependencies

This gem depends only on Ruby stdlib `yaml`. No external gems are allowed at runtime. Development/test gems (rspec, rubocop, rubocop-rspec) are in the dev group only.

**Rationale:** Every runtime dependency is an attack surface and a version conflict risk for the consuming application.

---

## Threat Model Notes

The configs being analyzed may come from untrusted sources (e.g., user-submitted PRs). The analyzer treats all string values in config files as opaque data — no string is interpreted as a file path, shell command, or URL. YAML is loaded with `permitted_classes: []` to prevent deserialization of non-standard objects.
