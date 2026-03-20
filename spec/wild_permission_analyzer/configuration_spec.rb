# frozen_string_literal: true

RSpec.describe WildPermissionAnalyzer::Configuration do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'has nil capabilities_path' do
      expect(config.capabilities_path).to be_nil
    end

    it 'has nil grants_path' do
      expect(config.grants_path).to be_nil
    end

    it 'has default risk_levels' do
      expect(config.risk_levels).to eq('low' => 1, 'medium' => 2, 'high' => 3, 'critical' => 4)
    end

    it 'defaults wildcard_risk_threshold to medium' do
      expect(config.wildcard_risk_threshold).to eq('medium')
    end

    it 'defaults max_prerequisite_depth to 10' do
      expect(config.max_prerequisite_depth).to eq(10)
    end
  end

  describe '#capabilities_path=' do
    it 'accepts a valid string path' do
      config.capabilities_path = '/tmp/capabilities.yml'
      expect(config.capabilities_path).to eq('/tmp/capabilities.yml')
    end

    it 'accepts nil' do
      config.capabilities_path = nil
      expect(config.capabilities_path).to be_nil
    end

    it 'raises ConfigurationError for non-string non-nil' do
      expect { config.capabilities_path = 123 }
        .to raise_error(WildPermissionAnalyzer::ConfigurationError)
    end
  end

  describe '#grants_path=' do
    it 'accepts a valid string path' do
      config.grants_path = '/tmp/grants.yml'
      expect(config.grants_path).to eq('/tmp/grants.yml')
    end

    it 'raises ConfigurationError for non-string non-nil' do
      expect { config.grants_path = :sym }
        .to raise_error(WildPermissionAnalyzer::ConfigurationError)
    end
  end

  describe '#wildcard_risk_threshold=' do
    it 'accepts a valid risk level key' do
      config.wildcard_risk_threshold = 'high'
      expect(config.wildcard_risk_threshold).to eq('high')
    end

    it 'raises ConfigurationError for unknown level' do
      expect { config.wildcard_risk_threshold = 'ultra' }
        .to raise_error(WildPermissionAnalyzer::ConfigurationError, /wildcard_risk_threshold/)
    end
  end

  describe '#max_prerequisite_depth=' do
    it 'accepts positive integer' do
      config.max_prerequisite_depth = 5
      expect(config.max_prerequisite_depth).to eq(5)
    end

    it 'raises ConfigurationError for zero' do
      expect { config.max_prerequisite_depth = 0 }
        .to raise_error(WildPermissionAnalyzer::ConfigurationError)
    end

    it 'raises ConfigurationError for non-integer' do
      expect { config.max_prerequisite_depth = 'ten' }
        .to raise_error(WildPermissionAnalyzer::ConfigurationError)
    end
  end

  describe '#freeze!' do
    it 'freezes the configuration' do
      config.freeze!
      expect(config).to be_frozen
    end

    it 'freezes the risk_levels hash' do
      config.freeze!
      expect(config.risk_levels).to be_frozen
    end

    it 'raises FrozenError on mutation after freeze' do
      config.freeze!
      expect { config.capabilities_path = '/new' }.to raise_error(FrozenError)
    end
  end

  describe 'module-level configure' do
    it 'configures and freezes in a block' do
      WildPermissionAnalyzer.configure do |c|
        c.capabilities_path = '/tmp/caps.yml'
        c.grants_path = '/tmp/grants.yml'
      end
      expect(WildPermissionAnalyzer.configuration.capabilities_path).to eq('/tmp/caps.yml')
      expect(WildPermissionAnalyzer.configuration).to be_frozen
    end
  end
end
