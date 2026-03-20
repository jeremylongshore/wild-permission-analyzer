# wild-permission-analyzer

Static audit of capability-gate permission configs for the wild ecosystem.

Part of the **wild** ecosystem. See [`../CLAUDE.md`](../CLAUDE.md) for ecosystem-level guidance.

## What It Does

`wild-permission-analyzer` is a Ruby gem that audits `capabilities.yml` and `grants.yml` files from [wild-capability-gate](https://github.com/jeremylongshore/wild-capability-gate) **before deployment**. It catches permission model mistakes statically so they never reach production.

Six analyzers run over your config files:

- **Consistency** — every capability referenced in a grant exists in capabilities
- **Risk** — wildcard grants on elevated capabilities, grants with no expiry date
- **Prerequisite** — missing, circular, and unsatisfiable prerequisite chains
- **Coverage** — per-caller view of what is granted vs denied
- **Orphan** — capabilities defined but never granted; grants referencing missing capabilities
- **Shadow** — explicit grants made redundant by wildcard grants from the same caller

## Quick Start

```ruby
require 'wild_permission_analyzer'

report = WildPermissionAnalyzer.audit(
  capabilities_path: 'config/capabilities.yml',
  grants_path: 'config/grants.yml'
)

puts report.summary.inspect
# { total_findings: 4, by_severity: { critical: 0, error: 1, warning: 2, info: 1 }, ... }

report.findings.each do |finding|
  puts "[#{finding.severity.upcase}] #{finding.type}: #{finding.message}"
end
```

### Export to Markdown

```ruby
md = WildPermissionAnalyzer::Export::MarkdownExporter.new.export(report)
File.write('audit-report.md', md)
```

### Export to JSON

```ruby
json = WildPermissionAnalyzer::Export::JsonExporter.new.export(report)
File.write('audit-report.json', json)
```

### Coverage for a specific caller

```ruby
analyzer = WildPermissionAnalyzer::Analyzers::CoverageAnalyzer.new
coverage = analyzer.coverage_for('ops-team', capabilities, grants)

puts "Granted: #{coverage.granted_capabilities}"
puts "Denied:  #{coverage.denied_capabilities}"
puts "Coverage: #{(coverage.coverage_ratio * 100).round(1)}%"
```

## Configuration

```ruby
WildPermissionAnalyzer.configure do |c|
  c.capabilities_path       = 'config/capabilities.yml'
  c.grants_path             = 'config/grants.yml'
  c.wildcard_risk_threshold = 'medium'   # flag wildcards on capabilities >= this risk level
  c.max_prerequisite_depth  = 10         # prevent runaway prerequisite chain traversal
end
```

See [000-docs/005-DR-REFF-configuration-reference.md](000-docs/005-DR-REFF-configuration-reference.md) for all parameters.

## Config File Formats

**capabilities.yml**

```yaml
capabilities:
  - name: "admin.jobs.retry"
    description: "Retry failed background jobs"
    risk_level: "medium"
    prerequisites:
      - "admin.jobs.view"
    tags: ["admin", "jobs"]
```

**grants.yml**

```yaml
grants:
  - caller_id: "ops-team"
    capabilities: ["admin.jobs.*"]
    context:
      environment: "production"
    expires_at: null
  - caller_id: "dev-intern"
    capabilities: ["admin.jobs.view"]
    context:
      environment: "staging"
    expires_at: "2026-06-01"
```

## Wildcard Matching

The `admin.jobs.*` pattern matches any capability whose name begins with `admin.jobs.`. Wildcards use `*` and support arbitrary depth (`admin.*` matches `admin.jobs.retry`).

## Requirements

- Ruby >= 3.2.0
- No runtime dependencies beyond stdlib `yaml`

## Development

```bash
bundle install
bundle exec rspec     # 217 specs, 0 failures
bundle exec rubocop   # 0 offenses
bundle exec rake      # default: rspec
```

## License

Nonstandard — Intent Solutions proprietary. See LICENSE.
