# frozen_string_literal: true

module WildPermissionAnalyzer
  class Configuration
    DEFAULT_RISK_LEVELS = { 'low' => 1, 'medium' => 2, 'high' => 3, 'critical' => 4 }.freeze

    attr_reader :capabilities_path, :grants_path, :risk_levels,
                :wildcard_risk_threshold, :max_prerequisite_depth

    def initialize
      @capabilities_path = nil
      @grants_path = nil
      @risk_levels = DEFAULT_RISK_LEVELS.dup
      @wildcard_risk_threshold = 'medium'
      @max_prerequisite_depth = 10
    end

    def capabilities_path=(value)
      check_frozen!
      unless value.nil? || value.is_a?(String)
        raise ConfigurationError, "capabilities_path must be a String, got: #{value.class}"
      end

      @capabilities_path = value
    end

    def grants_path=(value)
      check_frozen!
      unless value.nil? || value.is_a?(String)
        raise ConfigurationError, "grants_path must be a String, got: #{value.class}"
      end

      @grants_path = value
    end

    def risk_levels=(value)
      check_frozen!
      raise ConfigurationError, "risk_levels must be a Hash, got: #{value.class}" unless value.is_a?(Hash)

      @risk_levels = value
    end

    def wildcard_risk_threshold=(value)
      check_frozen!
      unless value.is_a?(String) && risk_levels.key?(value)
        raise ConfigurationError,
              "wildcard_risk_threshold must be one of #{risk_levels.keys.inspect}, got: #{value.inspect}"
      end

      @wildcard_risk_threshold = value
    end

    def max_prerequisite_depth=(value)
      check_frozen!
      unless value.is_a?(Integer) && value >= 1
        raise ConfigurationError, "max_prerequisite_depth must be a positive integer, got: #{value.inspect}"
      end

      @max_prerequisite_depth = value
    end

    def freeze!
      @risk_levels = @risk_levels.freeze
      freeze
    end

    private

    def check_frozen!
      raise FrozenError, "can't modify frozen #{self.class}" if frozen?
    end
  end
end
