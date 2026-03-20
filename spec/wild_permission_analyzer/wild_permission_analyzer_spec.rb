# frozen_string_literal: true

RSpec.describe WildPermissionAnalyzer do
  describe 'VERSION' do
    subject(:version) { WildPermissionAnalyzer::VERSION }

    it 'is a semver string' do
      expect(version).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
