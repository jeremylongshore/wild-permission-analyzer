# frozen_string_literal: true

module WildPermissionAnalyzer
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class LoadError < Error; end
  class AnalysisError < Error; end
  class ExportError < Error; end
end
