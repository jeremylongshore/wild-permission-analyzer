# Operator-Grade System Audit — wild-permission-analyzer

**Code:** AT-AUDT
**Date:** 2026-05-28
**Auditor:** Claude (operator-grade audit)
**Scope:** wild-permission-analyzer v0.1.0 — full repo at `/home/jeremy/000-projects/wild/wild-permission-analyzer/`
**Audience:** Senior Rails / Ruby engineer, first read, must be operational in 10 minutes.

---

## 1. Mission & Boundaries

`wild-permission-analyzer` is a Ruby library gem (no CLI, no daemon, no Rails engine) whose entire job is to read two YAML files — `capabilities.yml` and `grants.yml` from a sibling repo called `wild-capability-gate` — and produce a structured `AuditReport` describing what is wrong, risky, or redundant about the permission model declared in those files. It is an Archetype C tool in the wild ecosystem (`../CLAUDE.md` line: "SDLC Companion"): it runs in CI, in pre-deploy hooks, or in a developer's terminal — **never in a request hot path**. The mission is captured at [`000-docs/001-PP-PLAN-repo-blueprint.md:8-14`](001-PP-PLAN-repo-blueprint.md) and the archetype contract is reinforced at [`000-docs/003-TQ-STND-safety-model.md:9-11`](003-TQ-STND-safety-model.md).

**What it does**, by direct citation:

| Concern | Where |
|---|---|
| Parse `capabilities.yml` | [`lib/wild_permission_analyzer/loaders/capabilities_loader.rb`](../lib/wild_permission_analyzer/loaders/capabilities_loader.rb) |
| Parse `grants.yml` | [`lib/wild_permission_analyzer/loaders/grants_loader.rb`](../lib/wild_permission_analyzer/loaders/grants_loader.rb) |
| Six analyzers (consistency, risk, prerequisite, coverage, orphan, shadow) | [`lib/wild_permission_analyzer/analyzers/`](../lib/wild_permission_analyzer/analyzers/) |
| Orchestration | [`lib/wild_permission_analyzer/report/builder.rb`](../lib/wild_permission_analyzer/report/builder.rb) |
| Emit JSON | [`lib/wild_permission_analyzer/export/json_exporter.rb`](../lib/wild_permission_analyzer/export/json_exporter.rb) |
| Emit Markdown | [`lib/wild_permission_analyzer/export/markdown_exporter.rb`](../lib/wild_permission_analyzer/export/markdown_exporter.rb) |
| Public entrypoint `WildPermissionAnalyzer.audit(...)` | [`lib/wild_permission_analyzer.rb:45-55`](../lib/wild_permission_analyzer.rb) |

**What it explicitly does NOT do** (from [`003-TQ-STND-safety-model.md`](003-TQ-STND-safety-model.md) and [`CLAUDE.md` lines 23-29](../CLAUDE.md)):

- No runtime permission enforcement — that is `wild-capability-gate`'s job; this gem has no runtime dependency on it.
- No code-level static analysis — no AST parsing, no Rails RBAC introspection, no scanning of Ruby source.
- No file mutation — never writes back to `capabilities.yml` or `grants.yml`.
- No subprocess execution — no `system`, no backticks, no `Open3`, no `Kernel#exec`.
- No network I/O — air-gapped CI must work without changes.
- No runtime gem dependencies beyond stdlib `yaml`. The gemspec [`wild-permission-analyzer.gemspec:22`](../wild-permission-analyzer.gemspec) declares exactly one dep (`yaml`), and that is stdlib in Ruby 3.2+.

The boundary is unusually tight for a security/audit tool. There is no "scan a Rails app for `before_action :authorize` calls" feature, no Pundit/CanCanCan integration, no telemetry export to a SIEM. The unit of analysis is the pair of YAML files, full stop. Anything outside that scope is delegated to other gems in the `wild` ecosystem (`wild-permission-analyzer` is 1 of 10 — see `../CLAUDE.md` § "Ecosystem Structure").

---

## 2. Analysis Architecture

The gem is laid out as four collaborating layers: **loaders → models → analyzers → report builder / exporters**. The top-level module [`lib/wild_permission_analyzer.rb`](../lib/wild_permission_analyzer.rb) wires them.

### Layer 1: Loaders

Two loader classes, structurally identical:

- `Loaders::CapabilitiesLoader` ([`capabilities_loader.rb:16-21`](../lib/wild_permission_analyzer/loaders/capabilities_loader.rb)) — `load → parse_yaml → extract_entries → build_capability` per entry.
- `Loaders::GrantsLoader` ([`grants_loader.rb:16-21`](../lib/wild_permission_analyzer/loaders/grants_loader.rb)) — same shape.

Both use `YAML.safe_load(content, permitted_classes: [])` ([`capabilities_loader.rb:26`](../lib/wild_permission_analyzer/loaders/capabilities_loader.rb)), which is the hardened parser — no `Symbol`, no `Date`, no arbitrary Ruby classes can be deserialized. This matters because, per [`003-TQ-STND-safety-model.md:56`](003-TQ-STND-safety-model.md), the configs being audited may come from untrusted sources (e.g., user-submitted PRs).

The structural contract is enforced in `extract_entries`: a top-level Hash with a `capabilities` (resp. `grants`) Array key is required, else `LoadError`. Individual entries that fail validation (`valid_entry?`) return `nil` and are compacted away. This is the "raise on structure, skip on entries" rule from [AD-4 in `004-AT-ADEC-architecture-decisions.md:39-43`](004-AT-ADEC-architecture-decisions.md).

### Layer 2: Models

Five immutable value objects in [`lib/wild_permission_analyzer/models/`](../lib/wild_permission_analyzer/models/):

| Model | Key invariants |
|---|---|
| `Capability` | `==` and `hash` by `name` only; `prerequisites` + `tags` frozen on init |
| `Grant` | `==` by `caller_id` + `capabilities`; provides `wildcard_capabilities` and `expired?` helpers |
| `Finding` | Carries a typed symbol, severity, message, frozen evidence hash; `include Comparable` with `<=>` defined by `SEVERITY_RANKS` (critical=3, error=2, warning=1, info=0) — `Finding#<=>` ([`finding.rb:19-21`](../lib/wild_permission_analyzer/models/finding.rb)) inverts so `.sort` is critical-first |
| `CoverageReport` | Per-caller: granted set, denied set, **and `grant_chain`** — a `Hash { capability_name => [Grant, ...] }` that records *which grants resolved each capability* |
| `AuditReport` | Top-level result; `findings.sort.freeze` ([`audit_report.rb:11`](../lib/wild_permission_analyzer/models/audit_report.rb)) so callers can rely on severity ordering |

### Layer 3: Analyzers

Six concrete analyzers + one shared module, all under [`lib/wild_permission_analyzer/analyzers/`](../lib/wild_permission_analyzer/analyzers/). Every analyzer exposes the same one-method interface: `analyze(capabilities, grants) → [Finding, ...]`. This uniformity is what makes `Report::Builder#run_analyzers` ([`builder.rb:28-36`](../lib/wild_permission_analyzer/report/builder.rb)) a single `flat_map` over an array of analyzer instances.

| Analyzer | What it walks | Finding type(s) |
|---|---|---|
| `ConsistencyAnalyzer` | Each grant's explicit (non-wildcard) capability references vs the capability name set | `:missing_reference` (error) |
| `RiskAnalyzer` | Wildcard patterns expanded against the capability set, filtered by `wildcard_risk_threshold`; also no-expiry on elevated grants | `:wildcard_on_critical` (warning/error/critical, derived from cap risk_level), `:no_expiry_elevated` (warning) |
| `PrerequisiteAnalyzer` | Capability prerequisite DAG — missing nodes, cycles via bounded DFS, unsatisfiable prereqs in granted capabilities | `:missing_prerequisite` (error), `:circular_prerequisite` (critical), `:unsatisfiable_prerequisite` (error) |
| `CoverageAnalyzer` | Per-caller resolution — outputs `CoverageReport`s, not findings | (none — this analyzer is reporting, not flagging) |
| `OrphanAnalyzer` | Capabilities never matched by any grant pattern; grants pointing at missing capabilities (a cross-check against `ConsistencyAnalyzer`) | `:orphan_capability` (info), `:grant_references_missing_capability` (error) |
| `ShadowAnalyzer` | Per-caller: explicit grants that are already covered by a wildcard grant from the same caller | `:shadowed_grant` (warning) |

The `WildcardMatcher` module ([`wildcard_matcher.rb:12-25`](../lib/wild_permission_analyzer/analyzers/wildcard_matcher.rb)) is the shared building block. `matches?` short-circuits on pure-string patterns (no `*`), and for wildcard patterns escapes the pattern via `Regexp.escape` so dots are literal dots, then substitutes `\*` → `.*`. This is the single point at which the pattern language is defined; if it ever needs to support `?` or character classes, this is the file.

### Layer 4: Builder + exporters

`Report::Builder#build` ([`builder.rb:16-24`](../lib/wild_permission_analyzer/report/builder.rb)) runs five findings-producing analyzers (everything except coverage) via `flat_map`, then runs `CoverageAnalyzer` separately because its output shape is different, then bundles both into an `AuditReport`. Exporters consume an `AuditReport` and emit a string — JSON via `JSON.generate` ([`json_exporter.rb:14`](../lib/wild_permission_analyzer/export/json_exporter.rb)), Markdown via string concatenation of header / summary table / findings table / coverage table ([`markdown_exporter.rb:15-22`](../lib/wild_permission_analyzer/export/markdown_exporter.rb)). Both raise `ExportError` on non-`AuditReport` input.

The total surface is 985 LOC under `lib/` (per `wc -l`) — small enough to read in one sitting before changing anything.

---

## 3. The Critical Path

End-to-end, "engineer runs the analyzer → indexed permission surface → report":

```ruby
require 'wild_permission_analyzer'

report = WildPermissionAnalyzer.audit(
  capabilities_path: 'config/capabilities.yml',
  grants_path:       'config/grants.yml'
)
```

That one call ([`lib/wild_permission_analyzer.rb:45-55`](../lib/wild_permission_analyzer.rb)) drives the entire pipeline:

1. **Argument resolution.** `audit` first prefers its keyword args, then falls back to `configuration.capabilities_path` / `.grants_path`. If either is still nil, `ConfigurationError` is raised immediately ([line 49-50](../lib/wild_permission_analyzer.rb)).
2. **Load capabilities.** `Loaders::CapabilitiesLoader.load(cap_path)` reads the file, runs `YAML.safe_load`, validates the top-level shape, and builds `Capability` value objects, skipping any entry whose `name` is not a non-empty string. Returns `Array<Capability>`.
3. **Load grants.** Same shape — returns `Array<Grant>`. Each `Grant` carries its `capabilities` array (a mix of literal names and wildcard patterns like `"admin.jobs.*"`), `context` hash, and `expires_at` string (or nil).
4. **Construct the builder.** `Report::Builder.new(capabilities, grants)` captures both arrays plus the (currently frozen) global `WildPermissionAnalyzer.configuration`. No analyzers have run yet.
5. **Run findings analyzers.** `Builder#run_analyzers` ([`builder.rb:28-36`](../lib/wild_permission_analyzer/report/builder.rb)) instantiates `ConsistencyAnalyzer`, `RiskAnalyzer.new(@config)`, `PrerequisiteAnalyzer.new(@config)`, `OrphanAnalyzer`, and `ShadowAnalyzer`, then `flat_map`s each one's `#analyze(capabilities, grants)` over both arrays. Each analyzer walks its specific projection of the input (cap-name set, wildcard expansion, prerequisite DAG, per-caller grouping) and emits `Finding` instances.
6. **Run the coverage analyzer.** `CoverageAnalyzer#analyze` ([`coverage_analyzer.rb:6-11`](../lib/wild_permission_analyzer/analyzers/coverage_analyzer.rb)) groups grants by `caller_id`, calls `WildcardMatcher.resolve_patterns` to expand each grant's patterns against the capability-name list, and builds a `CoverageReport` per caller — including the `grant_chain` mapping each granted capability back to the grant(s) that resolved it (AD-5).
7. **Assemble `AuditReport`.** `AuditReport.new` sorts findings critical-first (via `Finding`'s `Comparable`) and freezes both arrays. The report timestamp is `Time.now` at construction.
8. **Engineer consumes the report.** Three common shapes — iterate `report.findings`, read `report.summary` (a hash with severity counts and totals), or call `report.findings_by_severity(:critical)` for a quick filter.

The expected CI exit-on-error pattern is in [`006-OD-GUID-operator-workflow-guide.md:27`](006-OD-GUID-operator-workflow-guide.md): `exit 1 if report.findings.any? { |f| [:error, :critical].include?(f.severity) }`.

---

## 4. Output Format(s)

Three output surfaces, all driven from the same `AuditReport` value object:

| Format | File | Shape |
|---|---|---|
| **In-process Ruby** | n/a — `AuditReport` itself | `findings: Array<Finding>` (sorted), `coverage_reports: Array<CoverageReport>`, `generated_at: Time`, plus `summary` hash and `findings_by_severity(sev)` filter |
| **JSON** | [`lib/wild_permission_analyzer/export/json_exporter.rb`](../lib/wild_permission_analyzer/export/json_exporter.rb) | `{ generated_at:, summary:, findings: [{type, severity, message, evidence}], coverage_reports: [{caller_id, granted_capabilities, denied_capabilities, coverage_ratio}] }` via `JSON.generate` |
| **Markdown** | [`lib/wild_permission_analyzer/export/markdown_exporter.rb`](../lib/wild_permission_analyzer/export/markdown_exporter.rb) | `# Permission Audit Report` header + `## Summary` table + `## Findings` table (severity / type / message) + `## Coverage by Caller` table (caller / granted / denied / coverage %) |

**Notably absent:** no CSV, no HTML, no SARIF, no JUnit XML. There is no plain-text "console" formatter either — when the operator guide ([`006-OD-GUID-operator-workflow-guide.md:13-28`](006-OD-GUID-operator-workflow-guide.md)) demonstrates a CI invocation, it does ad-hoc `puts` inline rather than calling a formatter. For CI logs that's fine; for a GitHub Actions annotation, a dashboard ingestion, or an IDE plugin, the consumer has to roll its own.

The Markdown exporter is mildly opinionated: severity icons are uppercase ASCII strings (`SEVERITY_ICONS = { critical: 'CRITICAL', error: 'ERROR', warning: 'WARN', info: 'INFO' }`, [line 8](../lib/wild_permission_analyzer/export/markdown_exporter.rb)) — explicitly not emoji, almost certainly because of the project-wide no-emoji preference. Pipe characters in messages are escaped to `\|` and backticks are replaced with single quotes ([line 86](../lib/wild_permission_analyzer/export/markdown_exporter.rb)) to keep table cells valid. There is no anchor generation, no per-finding deep link, and no grouping by caller in the findings section.

The JSON exporter rounds `coverage_ratio` to 4 decimals ([line 42](../lib/wild_permission_analyzer/export/json_exporter.rb)). Symbol values for `type` and `severity` round-trip through `JSON.generate` as strings — consumers parsing the JSON need to convert back to symbols if they want to pattern-match.

---

## 5. Failure Modes & Blast Radius

Because this gem is read-only and side-effect-free, the blast radius of any failure is bounded to the calling process: a thrown exception, a wrong finding, or a missed risk. Nothing the analyzer does can corrupt config, mutate state, or trigger a network call. That said, the failure modes that matter are:

### 5.1 Unparseable input

| Failure | Detection | Behavior | Error class |
|---|---|---|---|
| File missing | `Errno::ENOENT` in `File.read` | `LoadError` raised with path | [`capabilities_loader.rb:28`](../lib/wild_permission_analyzer/loaders/capabilities_loader.rb), `errors.rb:6` |
| YAML syntax invalid | `Psych::Exception` | `LoadError` with parser message | [`capabilities_loader.rb:30`](../lib/wild_permission_analyzer/loaders/capabilities_loader.rb) |
| Top-level key wrong (e.g., `capabilities:` is a string not an array) | `extract_entries` shape check | `LoadError` with structural reason | [`capabilities_loader.rb:35`](../lib/wild_permission_analyzer/loaders/capabilities_loader.rb) |
| Single entry malformed (missing `name`, non-string `name`, etc.) | `valid_entry?` predicate returns false | Entry returned as `nil`, then compacted — **silent skip** | [`capabilities_loader.rb:43, 54`](../lib/wild_permission_analyzer/loaders/capabilities_loader.rb) |
| Grant entry with non-string capabilities | `grep(String)` in `build_grant` | Non-strings stripped — silent | [`grants_loader.rb:49`](../lib/wild_permission_analyzer/loaders/grants_loader.rb) |

The silent-skip behavior is intentional (AD-4) but worth understanding: **a typo'd grant entry that drops a capability silently produces a smaller-than-expected `grants` array, which the downstream analyzers can't detect because they only see what made it through the loader**. There is no log line, no warning finding, no count comparison. The adversarial spec [`spec/adversarial/malformed_input_spec.rb:35-47`](../spec/adversarial/malformed_input_spec.rb) documents this contract but it's the kind of thing a reviewer should know.

### 5.2 Indirect / wildcard grant resolution drift

The wildcard semantics are defined in exactly one place ([`WildcardMatcher.matches?`](../lib/wild_permission_analyzer/analyzers/wildcard_matcher.rb)) and are deliberately simple: `*` is greedy, dots are literal. There are no character classes, no negation, no alternation. If the host `wild-capability-gate` runtime ever expands its pattern language (say, `admin.{jobs,users}.*`), this gem will **silently mis-resolve** because patterns the gate accepts will fail to match here. The risk catalog is: orphan-cap false positives, missed `wildcard_on_critical` flags, and incorrect coverage reports. There is no version pinning or compatibility check between the two gems' pattern languages. **This is the single highest-leverage failure mode**, and the audit found no test that explicitly pins the contract.

### 5.3 Non-standard host permission frameworks

The gem's worldview is: capabilities + grants in two YAML files with a fixed schema. If a downstream Rails app uses Pundit, CanCanCan, Rolify, action_policy, custom `before_action` callbacks, or any code-level permission scheme, **this gem has nothing to say about it**. There is no graceful degradation — the gem will simply fail to load the file (no `capabilities:` key) and raise `LoadError`. This is consistent with the scope in [`001-PP-PLAN-repo-blueprint.md:30-35`](001-PP-PLAN-repo-blueprint.md) but worth surfacing for any engineer who picks up the gem expecting general-purpose Rails RBAC audit.

### 5.4 Configuration mutation after `freeze!`

`Configuration#freeze!` is called at the end of every `WildPermissionAnalyzer.configure` block ([`wild_permission_analyzer.rb:37`](../lib/wild_permission_analyzer.rb)). Any subsequent setter raises `FrozenError` ([`configuration.rb:70`](../lib/wild_permission_analyzer/configuration.rb)). The test contract in [`006-OD-GUID-operator-workflow-guide.md:128-134`](006-OD-GUID-operator-workflow-guide.md) requires a `before` hook calling `reset_configuration!`. **Without that hook, tests that mutate config after a previous spec called `configure` will fail with `FrozenError` — not `ConfigurationError`** — which can be a confusing trace for a new contributor.

---

## 6. Trade-off Analysis

Six architecture decisions are documented in [`004-AT-ADEC-architecture-decisions.md`](004-AT-ADEC-architecture-decisions.md). The three with the most operational impact:

### Trade-off 1: Six separate analyzers vs one monolith (AD-1)

| Dimension | Detail |
|---|---|
| **Chosen** | Six analyzer classes, each with `analyze(capabilities, grants)`, orchestrated by `Report::Builder#run_analyzers` flat-mapping over an array |
| **Alternative** | A single `Auditor` class with private methods per concern; or a single multi-pass walker that emits all findings in one pass |
| **Why chosen** | Each analyzer has a distinct contract, distinct finding types, distinct inputs of interest. Independent testing is trivial (one spec file per analyzer in [`spec/wild_permission_analyzer/analyzers/`](../spec/wild_permission_analyzer/analyzers/)). Adding/removing analyzers is a one-line change |
| **Cost** | Each analyzer rebuilds its own index of the capability set (e.g., `cap_index = capabilities.to_h { \|c\| [c.name, c] }` in [`risk_analyzer.rb:11`](../lib/wild_permission_analyzer/analyzers/risk_analyzer.rb), again in `prerequisite_analyzer.rb:11`, again in `consistency_analyzer.rb:7`). For 500 caps + 200 grants the adversarial spec proves this stays under 5s ([`edge_cases_spec.rb:30-46`](../spec/adversarial/edge_cases_spec.rb)), so the cost is bounded — but at 10K caps it would start to bite |
| **When it breaks** | If two analyzers ever need to cooperate (e.g., "skip risk findings on shadowed grants"), the current shape forces awkward cross-references. Today there are none |

### Trade-off 2: `WildcardMatcher` as a module, not a class (AD-2)

| Dimension | Detail |
|---|---|
| **Chosen** | A `module` with `self.matches?` and `self.resolve_patterns` — pure functions, no state |
| **Alternative** | A `WildcardMatcher.new(patterns)` instance that caches compiled regexes per pattern across calls |
| **Why chosen** | The matcher is a pure function and is called from tight loops; making it stateless avoids allocation overhead and makes the intent explicit |
| **Cost** | Every call to `matches?` with a wildcard pattern allocates a new `Regexp` ([`wildcard_matcher.rb:15-16`](../lib/wild_permission_analyzer/analyzers/wildcard_matcher.rb)) — `Regexp.escape(pattern).gsub('\\*', '.*')` runs, then `Regexp.new(...)` runs, then `.match?` runs. For a single audit with 100 patterns × 500 capabilities that's 50K regex compiles. Ruby's `Regexp.new` is not cheap |
| **When it breaks** | Performance — at the 10K cap × 1K grant scale this dominates wall time. A memoized `@regex_cache[pattern] ||= ...` (kept in a `Hash` at module level or threaded through analyzer state) would be a one-screen change with measurable wins. **Recommended for v2** |

### Trade-off 3: Loaders raise on structure, skip on entries (AD-4)

| Dimension | Detail |
|---|---|
| **Chosen** | `LoadError` on missing file / invalid YAML / wrong top-level shape; silent skip (compact away nil) on a single malformed entry |
| **Alternative 1** | Strict: any malformed entry raises and aborts the entire audit |
| **Alternative 2** | Permissive-with-findings: malformed entries emit a `Finding` of type `:malformed_entry` |
| **Why chosen** | Rationale in [AD-4](004-AT-ADEC-architecture-decisions.md): "A structurally invalid file means the audit cannot proceed; a single bad entry should not abort analysis of the rest" |
| **Cost** | The silent-skip path means an operator can never tell from the `AuditReport` that two of their 200 grants were silently dropped at load time. There is no `loader_warnings` field on `AuditReport`, no skipped-entry count in `summary`. **This is the highest-impact gap in the current shape** |
| **When it breaks** | Any time someone fat-fingers a grant (`callerid: foo` instead of `caller_id: foo`) — the grant vanishes, the audit reports green, and the production gate doesn't know either |

Three more decisions are documented but lower-leverage: `Finding includes Comparable` (AD-3, the cleanest), `CoverageReport carries grant_chain` (AD-5, enables shadow detection and "why does X have Y?" answering), `Configuration#freeze!` for immutability (AD-6, mirrors Rails config). `Capability` and `Grant` do not implement `<=>` (AD-7) because no universal sort order exists — order-of-source-file is the default.

---

## 7. Operator Playbook

The reference flow is in [`006-OD-GUID-operator-workflow-guide.md`](006-OD-GUID-operator-workflow-guide.md). Distilled:

### 7.1 Local one-shot audit

```bash
bundle add wild-permission-analyzer
ruby -r wild_permission_analyzer -e '
  report = WildPermissionAnalyzer.audit(
    capabilities_path: "config/capabilities.yml",
    grants_path:       "config/grants.yml"
  )
  puts report.summary.inspect
  report.findings.each { |f| puts "[#{f.severity.upcase}] #{f.type}: #{f.message}" }
'
```

### 7.2 CI gate (exit non-zero on error/critical)

```bash
ruby -r wild_permission_analyzer -e '
  report = WildPermissionAnalyzer.audit(
    capabilities_path: ENV.fetch("CAPS_PATH", "config/capabilities.yml"),
    grants_path:       ENV.fetch("GRANTS_PATH", "config/grants.yml")
  )
  exit 1 if report.findings.any? { |f| [:error, :critical].include?(f.severity) }
'
```

### 7.3 Interpreting findings

Map each finding type to the action in the table at [`006-OD-GUID-operator-workflow-guide.md:46-56`](006-OD-GUID-operator-workflow-guide.md). The most common live cases:

| Finding | Most likely cause | First fix |
|---|---|---|
| `:missing_reference` / `:grant_references_missing_capability` | Capability renamed in caps.yml but grant wasn't updated | Rename in `grants.yml` or restore the cap |
| `:wildcard_on_critical` | Ops gave `admin.*` to a service that only needs `admin.jobs.*` | Tighten the wildcard or set `expires_at` |
| `:no_expiry_elevated` | Long-running ops grant has no rotation | Set `expires_at: <ISO date>`; downgrade or document |
| `:circular_prerequisite` | Refactor introduced A → B → A | Break the cycle; this is critical because it makes prereq validation undecidable |
| `:shadowed_grant` | Explicit cap left over after a wildcard was added | Delete the explicit row from `grants.yml` |
| `:orphan_capability` | Cap defined but no one grants it | Either grant it or delete the cap entry |

### 7.4 Baselining drift

The gem does not ship a baseline mechanism. To detect drift between runs the operator must:

1. Persist the JSON export from a known-good run (e.g., `.audit-baseline.json` checked into the repo).
2. Diff the new JSON against the baseline in CI — by `(type, severity, evidence)` tuple.

There is no built-in `Diff` class, no `--baseline` flag, no "new since baseline" findings filter. **This is the most obvious v2 feature.**

### 7.5 Integration sketch

In a Rails app deploying via GitHub Actions, the recommended shape is a job step run before any deploy:

```yaml
- name: Audit capability config
  run: |
    bundle exec ruby -r wild_permission_analyzer -e '
      report = WildPermissionAnalyzer.audit(
        capabilities_path: "config/capabilities.yml",
        grants_path:       "config/grants.yml"
      )
      File.write("audit.json", WildPermissionAnalyzer::Export::JsonExporter.new.export(report))
      File.write("audit.md",   WildPermissionAnalyzer::Export::MarkdownExporter.new.export(report))
      exit 1 if report.findings.any? { |f| [:error, :critical].include?(f.severity) }
    '
- uses: actions/upload-artifact@v4
  if: always()
  with:
    name: permission-audit
    path: audit.*
```

---

## 8. Recommendations for v2

Honest list, ranked by leverage:

1. **Baseline + drift detection.** The single most-asked-for feature for any auditor: `WildPermissionAnalyzer.audit(..., baseline: 'audit-baseline.json')` returning only *new* findings. Without this, every audit either fails (because some findings already existed) or requires the operator to maintain an out-of-band ignore list.
2. **Loader warnings exposed on `AuditReport`.** Add a `loader_warnings: Array<String>` field. Each silent-skip in `Loaders::*Loader` appends a one-line description (file, entry index, reason). Surface in summary as `skipped_entries:` count. This closes the highest-impact gap from §5.1 / Trade-off 3 without changing the "skip don't raise" semantics.
3. **Wildcard pattern compatibility test against `wild-capability-gate`.** A shared fixture set, run from both gems, asserting `WildcardMatcher.matches?` agrees with the gate's runtime matcher on a corpus of patterns. Today the two implementations could drift silently (§5.2).
4. **Regex memoization in `WildcardMatcher`.** One-screen change, measurable performance win at scale (Trade-off 2).
5. **SARIF exporter.** Industry-standard format for code-scanning tools; would let the audit output land natively in GitHub Code Scanning alerts and IDE inline.
6. **CLI binary.** A `bin/wild-permission-analyzer` shipping with the gem, so the CI step is `bundle exec wild-permission-analyzer --caps config/capabilities.yml --grants config/grants.yml --format json` instead of an inline `ruby -e` block. Reduces the chance of subtle CI shell-quoting bugs.
7. **A `--strict` mode** that elevates `:orphan_capability` and `:no_expiry_elevated` from warning/info to error, for shops that want a tighter gate without adding custom logic.

What it should **not** do in v2: grow runtime gem dependencies, add network I/O, add code-level static analysis, or grow into a general-purpose Rails RBAC analyzer. The boundary is a feature.

---

## Audit Findings Summary

This is a tightly-scoped, well-documented v1 library. 985 LOC under `lib/`, 1,940 LOC of specs (217 examples, 0 failures, 0 RuboCop offenses per `CLAUDE.md:13`), six architecture decisions written down before they ossify, and a safety model that says "no" loudly to subprocesses, network I/O, file mutation, and runtime deps. The 4-layer architecture (loaders → models → analyzers → builder/exporters) is easy to read and easy to extend. Cross-repo dependency risk: the wildcard matcher's pattern language is the implicit contract with `wild-capability-gate`; a drift there would silently mis-resolve grants in production. Most impactful v2 gap: no drift-baseline support and silent loader skips that don't surface on the `AuditReport`.
