# frozen_string_literal: true

module WildPermissionAnalyzer
  module Report
    class Builder
      def initialize(
        capabilities,
        grants,
        config: WildPermissionAnalyzer.configuration
      )
        @capabilities = capabilities
        @grants = grants
        @config = config
      end

      def build
        findings = run_analyzers
        coverage_reports = coverage_analyzer.analyze(@capabilities, @grants)

        Models::AuditReport.new(
          findings: findings,
          coverage_reports: coverage_reports
        )
      end

      private

      def run_analyzers
        [
          Analyzers::ConsistencyAnalyzer.new,
          Analyzers::RiskAnalyzer.new(@config),
          Analyzers::PrerequisiteAnalyzer.new(@config),
          Analyzers::OrphanAnalyzer.new,
          Analyzers::ShadowAnalyzer.new
        ].flat_map { |a| a.analyze(@capabilities, @grants) }
      end

      def coverage_analyzer
        Analyzers::CoverageAnalyzer.new
      end
    end
  end
end
