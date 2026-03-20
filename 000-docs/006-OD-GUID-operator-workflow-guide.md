# Operator Workflow Guide — wild-permission-analyzer

**Code:** OD-GUID
**Status:** v1

---

## Typical CI workflow

Add to your CI pipeline after config file changes:

```bash
ruby -e "
require 'wild_permission_analyzer'

report = WildPermissionAnalyzer.audit(
  capabilities_path: 'config/capabilities.yml',
  grants_path:       'config/grants.yml'
)

# Print findings
report.findings.each do |f|
  puts \"[#{f.severity.upcase}] #{f.type}: #{f.message}\"
end

# Fail CI on errors or criticals
exit 1 if report.findings.any? { |f| [:error, :critical].include?(f.severity) }
"
```

---

## Reading findings

Each finding has four attributes:

| Attribute | Description |
|-----------|-------------|
| `type` | Symbol identifying what was detected |
| `severity` | `:info`, `:warning`, `:error`, or `:critical` |
| `message` | Human-readable explanation |
| `evidence` | Hash with relevant keys for programmatic use |

### Finding type reference

| Type | Meaning | Action |
|------|---------|--------|
| `:missing_reference` | Grant references a capability name that does not exist | Add the capability or fix the grant |
| `:wildcard_on_critical` | Wildcard pattern covers a high/critical capability | Use explicit names or add expiry |
| `:no_expiry_elevated` | Elevated grant has no expiry date | Add `expires_at` or document the exception |
| `:missing_prerequisite` | Capability requires an undefined prerequisite | Define the prerequisite in capabilities.yml |
| `:circular_prerequisite` | Prerequisite chain is circular | Break the cycle |
| `:unsatisfiable_prerequisite` | Granted capability has an unsatisfiable prerequisite | Fix the prerequisite chain or remove the grant |
| `:orphan_capability` | Capability defined but never granted | Either grant it or remove it |
| `:grant_references_missing_capability` | Orphan analyzer cross-check | Same as `:missing_reference` |
| `:shadowed_grant` | Explicit grant is redundant due to wildcard from same caller | Remove the explicit grant |

---

## Exporting reports

### Markdown (for PR review or Slack posting)

```ruby
md = WildPermissionAnalyzer::Export::MarkdownExporter.new.export(report)
File.write('audit-report.md', md)
```

### JSON (for dashboards or further processing)

```ruby
json = WildPermissionAnalyzer::Export::JsonExporter.new.export(report)
File.write('audit-report.json', json)
```

---

## Coverage analysis for a specific caller

```ruby
require 'wild_permission_analyzer'

capabilities = WildPermissionAnalyzer::Loaders::CapabilitiesLoader.load('config/capabilities.yml')
grants       = WildPermissionAnalyzer::Loaders::GrantsLoader.load('config/grants.yml')

analyzer = WildPermissionAnalyzer::Analyzers::CoverageAnalyzer.new
coverage = analyzer.coverage_for('ops-team', capabilities, grants)

puts "Granted (#{coverage.granted_capabilities.size}):"
coverage.granted_capabilities.each { |c| puts "  + #{c}" }

puts "\nDenied (#{coverage.denied_capabilities.size}):"
coverage.denied_capabilities.each { |c| puts "  - #{c}" }

puts "\nCoverage: #{(coverage.coverage_ratio * 100).round(1)}%"
```

---

## Adjusting risk thresholds

To only flag wildcards on high or critical capabilities (and ignore medium):

```ruby
WildPermissionAnalyzer.configure do |c|
  c.capabilities_path       = 'config/capabilities.yml'
  c.grants_path             = 'config/grants.yml'
  c.wildcard_risk_threshold = 'high'
end
```

---

## Custom risk levels

If your `capabilities.yml` uses non-standard risk levels:

```ruby
WildPermissionAnalyzer.configure do |c|
  c.risk_levels = { 'read' => 1, 'write' => 2, 'admin' => 3, 'superadmin' => 4 }
  c.wildcard_risk_threshold = 'admin'
end
```

---

## Running in tests

```ruby
RSpec.configure do |config|
  config.before do
    WildPermissionAnalyzer.reset_configuration!
  end
end
```

This ensures each spec starts with a clean, unfrozen configuration.
