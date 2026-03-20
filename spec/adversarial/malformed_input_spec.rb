# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'Malformed input handling' do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  describe 'CapabilitiesLoader with malformed YAML' do
    it 'raises LoadError for completely invalid YAML' do
      path = File.join(tmpdir, 'caps.yml')
      File.write(path, "---\n: : :\nbroken: [unterminated")
      expect do
        WildPermissionAnalyzer::Loaders::CapabilitiesLoader.load(path)
      end.to raise_error(WildPermissionAnalyzer::LoadError)
    end

    it 'raises LoadError when capabilities key is a string not an array' do
      path = File.join(tmpdir, 'caps.yml')
      File.write(path, 'capabilities: not-an-array')
      expect do
        WildPermissionAnalyzer::Loaders::CapabilitiesLoader.load(path)
      end.to raise_error(WildPermissionAnalyzer::LoadError)
    end

    it 'raises LoadError when file is empty' do
      path = File.join(tmpdir, 'caps.yml')
      File.write(path, '')
      expect do
        WildPermissionAnalyzer::Loaders::CapabilitiesLoader.load(path)
      end.to raise_error(WildPermissionAnalyzer::LoadError)
    end

    it 'skips entries that are not hashes' do
      entries = ['just a string', nil, { 'name' => 'valid.cap' }]
      path = write_capabilities_yaml(entries, tmpdir)
      caps = WildPermissionAnalyzer::Loaders::CapabilitiesLoader.load(path)
      expect(caps.map(&:name)).to eq(['valid.cap'])
    end

    it 'handles integer name values by skipping them' do
      entries = [{ 'name' => 42 }, { 'name' => 'valid.cap' }]
      path = write_capabilities_yaml(entries, tmpdir)
      caps = WildPermissionAnalyzer::Loaders::CapabilitiesLoader.load(path)
      expect(caps.map(&:name)).to eq(['valid.cap'])
    end

    it 'handles nil prerequisites gracefully' do
      entries = [{ 'name' => 'cap.one', 'prerequisites' => nil }]
      path = write_capabilities_yaml(entries, tmpdir)
      caps = WildPermissionAnalyzer::Loaders::CapabilitiesLoader.load(path)
      expect(caps.first.prerequisites).to eq([])
    end
  end

  describe 'GrantsLoader with malformed YAML' do
    it 'raises LoadError for completely invalid YAML' do
      path = File.join(tmpdir, 'grants.yml')
      File.write(path, 'grants: [bad: yaml: broken')
      expect do
        WildPermissionAnalyzer::Loaders::GrantsLoader.load(path)
      end.to raise_error(WildPermissionAnalyzer::LoadError)
    end

    it 'raises LoadError when grants key is absent' do
      path = File.join(tmpdir, 'grants.yml')
      File.write(path, 'roles: []')
      expect do
        WildPermissionAnalyzer::Loaders::GrantsLoader.load(path)
      end.to raise_error(WildPermissionAnalyzer::LoadError)
    end

    it 'skips non-hash entries' do
      entries = [nil, 'string entry', { 'caller_id' => 'valid', 'capabilities' => ['cap.one'] }]
      path = write_grants_yaml(entries, tmpdir)
      grants = WildPermissionAnalyzer::Loaders::GrantsLoader.load(path)
      expect(grants.size).to eq(1)
    end

    it 'filters out non-string capability values' do
      entries = [{ 'caller_id' => 'x', 'capabilities' => [42, nil, 'valid.cap'] }]
      path = write_grants_yaml(entries, tmpdir)
      grants = WildPermissionAnalyzer::Loaders::GrantsLoader.load(path)
      expect(grants.first.capabilities).to eq(['valid.cap'])
    end
  end

  describe 'Finding model with invalid input' do
    it 'raises ArgumentError for unknown severity' do
      expect do
        WildPermissionAnalyzer::Models::Finding.new(type: :foo, severity: :unknown_level, message: 'x')
      end.to raise_error(ArgumentError)
    end
  end

  describe 'Analyzers with empty inputs' do
    let(:analyzers) do
      [
        WildPermissionAnalyzer::Analyzers::ConsistencyAnalyzer.new,
        WildPermissionAnalyzer::Analyzers::RiskAnalyzer.new,
        WildPermissionAnalyzer::Analyzers::PrerequisiteAnalyzer.new,
        WildPermissionAnalyzer::Analyzers::CoverageAnalyzer.new,
        WildPermissionAnalyzer::Analyzers::OrphanAnalyzer.new,
        WildPermissionAnalyzer::Analyzers::ShadowAnalyzer.new
      ]
    end

    it 'handles empty capabilities and grants without raising' do
      analyzers.each do |analyzer|
        expect { analyzer.analyze([], []) }.not_to raise_error
      end
    end
  end

  describe 'Exporters with invalid input' do
    it 'JsonExporter raises ExportError for nil' do
      expect { WildPermissionAnalyzer::Export::JsonExporter.new.export(nil) }
        .to raise_error(WildPermissionAnalyzer::ExportError)
    end

    it 'MarkdownExporter raises ExportError for array' do
      expect { WildPermissionAnalyzer::Export::MarkdownExporter.new.export([]) }
        .to raise_error(WildPermissionAnalyzer::ExportError)
    end
  end
end
