# Configuration Reference — wild-permission-analyzer

**Code:** DR-REFF
**Status:** v1

---

## Overview

Configuration is set once via `WildPermissionAnalyzer.configure`. After the block completes, `freeze!` is called automatically. Mutation after freeze raises `FrozenError`. Use `reset_configuration!` in test `before` hooks.

```ruby
WildPermissionAnalyzer.configure do |c|
  c.capabilities_path       = 'config/capabilities.yml'
  c.grants_path             = 'config/grants.yml'
  c.wildcard_risk_threshold = 'medium'
  c.max_prerequisite_depth  = 10
end
```

---

## Parameters

### capabilities_path

| Attribute | Value |
|-----------|-------|
| Type | `String` or `nil` |
| Default | `nil` |
| Required | Yes, if using `WildPermissionAnalyzer.audit` without explicit path |

Path to `capabilities.yml`. Can also be passed directly to `WildPermissionAnalyzer.audit(capabilities_path: ...)`.

---

### grants_path

| Attribute | Value |
|-----------|-------|
| Type | `String` or `nil` |
| Default | `nil` |
| Required | Yes, if using `WildPermissionAnalyzer.audit` without explicit path |

Path to `grants.yml`. Can also be passed directly to `WildPermissionAnalyzer.audit(grants_path: ...)`.

---

### risk_levels

| Attribute | Value |
|-----------|-------|
| Type | `Hash` (String keys, Integer values) |
| Default | `{ 'low' => 1, 'medium' => 2, 'high' => 3, 'critical' => 4 }` |
| Required | No |

Maps risk level names used in capabilities.yml to integer ranks. Higher rank means higher risk. Used by `RiskAnalyzer` to evaluate threshold comparisons.

If you extend this with custom levels, also update `wildcard_risk_threshold` to reference a key that exists in your custom `risk_levels`.

---

### wildcard_risk_threshold

| Attribute | Value |
|-----------|-------|
| Type | `String` |
| Default | `'medium'` |
| Valid values | Any key present in `risk_levels` |

Wildcard grant patterns that cover capabilities at or above this risk rank will be flagged as `:wildcard_on_critical` findings. Set to `'high'` to only flag wildcards on high/critical capabilities.

---

### max_prerequisite_depth

| Attribute | Value |
|-----------|-------|
| Type | `Integer` |
| Default | `10` |
| Minimum | `1` |

Maximum depth the prerequisite chain traversal will follow before halting. Prevents runaway recursion in the presence of deeply nested (or accidentally circular) prerequisite chains. Chains that hit this limit are reported as potentially circular.

---

## Audit convenience method

`WildPermissionAnalyzer.audit(capabilities_path: nil, grants_path: nil)` accepts keyword arguments that override the configured paths. If both are nil and the configuration also has nil paths, `ConfigurationError` is raised.

```ruby
# Use configured paths
WildPermissionAnalyzer.configure do |c|
  c.capabilities_path = 'config/capabilities.yml'
  c.grants_path       = 'config/grants.yml'
end
report = WildPermissionAnalyzer.audit

# Override paths inline
report = WildPermissionAnalyzer.audit(
  capabilities_path: '/tmp/test-caps.yml',
  grants_path:       '/tmp/test-grants.yml'
)
```
