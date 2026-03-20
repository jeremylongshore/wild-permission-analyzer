# frozen_string_literal: true

require_relative 'lib/wild_permission_analyzer/version'

Gem::Specification.new do |spec|
  spec.name = 'wild-permission-analyzer'
  spec.version = WildPermissionAnalyzer::VERSION
  spec.authors = ['Intent Solutions']
  spec.summary = 'Static audit of capability-gate permission configs'
  spec.description = 'Library for statically auditing wild-capability-gate YAML configs ' \
                     '(capabilities.yml and grants.yml) for correctness, completeness, ' \
                     'risk patterns, coverage gaps, and orphaned or shadowed entries.'
  spec.homepage = 'https://github.com/jeremylongshore/wild-permission-analyzer'
  spec.license = 'Nonstandard'
  spec.required_ruby_version = '>= 3.2.0'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_dependency 'yaml', '>= 0'
end
