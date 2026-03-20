# frozen_string_literal: true

require_relative 'wild_permission_analyzer/version'
require_relative 'wild_permission_analyzer/errors'
require_relative 'wild_permission_analyzer/configuration'

require_relative 'wild_permission_analyzer/models/capability'
require_relative 'wild_permission_analyzer/models/grant'
require_relative 'wild_permission_analyzer/models/finding'
require_relative 'wild_permission_analyzer/models/coverage_report'
require_relative 'wild_permission_analyzer/models/audit_report'

require_relative 'wild_permission_analyzer/loaders/capabilities_loader'
require_relative 'wild_permission_analyzer/loaders/grants_loader'

require_relative 'wild_permission_analyzer/analyzers/wildcard_matcher'
require_relative 'wild_permission_analyzer/analyzers/consistency_analyzer'
require_relative 'wild_permission_analyzer/analyzers/risk_analyzer'
require_relative 'wild_permission_analyzer/analyzers/prerequisite_analyzer'
require_relative 'wild_permission_analyzer/analyzers/coverage_analyzer'
require_relative 'wild_permission_analyzer/analyzers/orphan_analyzer'
require_relative 'wild_permission_analyzer/analyzers/shadow_analyzer'

require_relative 'wild_permission_analyzer/report/builder'

require_relative 'wild_permission_analyzer/export/json_exporter'
require_relative 'wild_permission_analyzer/export/markdown_exporter'

module WildPermissionAnalyzer
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      configuration.freeze!
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Convenience: load both files and run the full audit.
    def audit(capabilities_path: nil, grants_path: nil)
      cap_path = capabilities_path || configuration.capabilities_path
      gr_path  = grants_path || configuration.grants_path

      raise ConfigurationError, 'capabilities_path must be set' if cap_path.nil?
      raise ConfigurationError, 'grants_path must be set' if gr_path.nil?

      capabilities = Loaders::CapabilitiesLoader.load(cap_path)
      grants       = Loaders::GrantsLoader.load(gr_path)
      Report::Builder.new(capabilities, grants).build
    end
  end
end
