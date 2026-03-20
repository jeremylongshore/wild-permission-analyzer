# Architecture Decisions — wild-permission-analyzer

**Code:** AT-ADEC
**Status:** v1

---

## AD-1: Six separate analyzer classes rather than one monolith

**Decision:** Each analysis concern (consistency, risk, prerequisite, coverage, orphan, shadow) is its own class with an `analyze(capabilities, grants)` method.

**Rationale:** Each analyzer has a distinct contract, different inputs of interest, and different finding types. Separating them makes each independently testable and makes it easy to add/remove/replace individual checks. The `Report::Builder` assembles results.

**Consequence:** The builder is a thin orchestrator. Adding a new analyzer requires one line in `Builder#run_analyzers`.

---

## AD-2: WildcardMatcher as a module, not a class

**Decision:** Wildcard matching is a stateless module with class methods rather than an instantiable object.

**Rationale:** Matching is a pure function with no state. Making it a module makes the intent clear and avoids the overhead of object allocation in tight loops.

**Consequence:** Analyzers call `WildcardMatcher.matches?` and `WildcardMatcher.resolve_patterns` directly.

---

## AD-3: Finding severity ordering via Comparable, not external sort keys

**Decision:** `Finding` includes `Comparable` with `<=>` defined by `SEVERITY_RANKS`. The `AuditReport` sorts with `.sort`.

**Rationale:** Keeping the sort order with the model keeps concerns together. If severity levels change, there is one place to update.

**Consequence:** `report.findings` is always sorted critical-first. This is a guaranteed invariant callers can rely on.

---

## AD-4: Loaders raise on structure, skip on entries

**Decision:** Structural errors (missing file, wrong YAML, missing top-level key) raise `LoadError`. Malformed individual entries return `nil` and are compacted away.

**Rationale:** A structurally invalid config file means the audit cannot proceed at all — that is always a hard error. A single malformed entry in a well-formed file should not abort analysis of the other entries.

---

## AD-5: CoverageReport includes grant_chain

**Decision:** `CoverageReport` carries a `grant_chain` hash mapping each granted capability name to the array of grants that cover it.

**Rationale:** This allows callers to answer "why does ops-team have admin.jobs.retry?" — the chain points to the specific grant (or grants) that resolved it. It also makes shadow detection straightforward.

---

## AD-6: Configuration immutability via freeze!

**Decision:** `Configuration#freeze!` is called at the end of `configure`. Subsequent mutation attempts raise `FrozenError`. Tests call `reset_configuration!` in a before hook.

**Rationale:** Frozen configuration is easy to reason about during an analyzer run. This pattern mirrors other Ruby gems (Rails config, for instance).

---

## AD-7: No Comparable on Capability or Grant

**Decision:** `Capability` and `Grant` implement `==` and `hash` for set/hash membership but not `<=>`.

**Rationale:** There is no natural sort order for capabilities or grants that would be universally useful. Results are returned in the order they appear in the source files. Callers that want a specific order can sort the output themselves.
